{
  Copyright (c) 2022-2022 Trung Le (Kagamma).
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
}

unit CastleSpine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Generics.Collections, fpjsonrtti, Spine,
  {$ifdef GLES}
  CastleGLES,
  {$else}
  GL, GLExt,
  {$endif}
  {$ifdef CASTLE_DESIGN_MODE}
  PropEdits, CastlePropEdits, CastleDebugTransform,
  {$endif}
  CastleVectors, CastleSceneCore, CastleApplicationProperties, CastleTransform, CastleComponentSerialize,
  CastleBoxes, CastleUtils, CastleLog, CastleRenderContext, CastleGLShaders, CastleDownload, CastleURIUtils,
  CastleGLImages;

type
  PCastleSpineVertex = ^TCastleSpineVertex;
  TCastleSpineVertex = packed record
    Vertex: TVector2;
    TexCoord: TVector2;
    Color: TVector4;
  end;

  TCastleSpine = class(TCastleSceneCore)
  strict private
    FURL: String;
    FIsGLContextInitialized: Boolean;
    FSpAtlas: PspAtlas;
    FSpSkeletonJson: PspSkeletonJson;
    FSpSkeletonData: PspSkeletonData;
    FSpAnimationStateData: PspAnimationStateData;
    FSpSkeleton: PspSkeleton;
    FSpAnimationState: PSpAnimationState;
    procedure GLContextOpen;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadSpine(const AURL: String);
    procedure GLContextClose; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure LocalRender(const Params: TRenderParams); override;
  published
    property URL: String read FURL write LoadSpine;
  end;

implementation

var
  WorldVerticesPositions: array[0..(4096 * 3 - 1)] of Single;
  SpineVertices: array[0..(High(WorldVerticesPositions) div 3) - 1] of TCastleSpineVertex;

{ Provide loader functions for Spine }
procedure LoaderLoad(FileName: PChar; var Data: Pointer; var Size: LongWord); cdecl;
var
  S: String;
  MS: TMemoryStream;
begin
  try
    S := FileName;
    MS := Download(S, [soForceMemoryStream]) as TMemoryStream;
    // Data is managed by spine-c, so we call malloc
    Data := _spMalloc(Size, nil, 0);
    Size := MS.Size;
    // Copy data from MS to Data
    Move(MS.Memory^, Data^, Size);
    //
    MS.Free;
  except
    // We ignore exception, and return null instead
    on E: Exception do
    begin
      WritelnLog('Spine Error', 'LoaderLoad: ' + E.Message + ' while loading ' + S);
      Data := nil;
      Size := 0;
    end;
  end;
end;

procedure LoaderLoadTexture(FileName: PChar; var ObjPas: TObject; var Width, Height: Integer);
var
  Image: TDrawableImage;
begin
  Image := TDrawableImage.Create(FileName, True);
  ObjPas := Image;
  Width := Image.Image.Width;
  Height := Image.Image.Height;
end;

procedure LoaderFreeTexture(ObjPas: TObject);
begin
  ObjPas.Free;
end;

{ ----- TCastleSpine ----- }

procedure TCastleSpine.GLContextOpen;
begin
  if not ApplicationProperties.IsGLContextOpen then Exit;
  if Self.FIsGLContextInitialized then Exit;
  // TODO: Handle resources when OpenGL context is opened
  Spine_Loader_RegisterLoadRoutine(@LoaderLoad);
  Spine_Loader_RegisterLoadTextureRoutine(@LoaderLoadTexture);
  Spine_Loader_RegisterFreeTextureRoutine(@LoaderFreeTexture);
end;

procedure TCastleSpine.GLContextClose;
begin
  if Self.FIsGLContextInitialized then
  begin
    // TODO: Handle resources when OpenGL context is closed
    Self.FIsGLContextInitialized := False;
  end;
  inherited;
end;

constructor TCastleSpine.Create(AOwner: TComponent);
begin
  inherited;
end;

destructor TCastleSpine.Destroy;
begin
  if Self.FSpAtlas <> nil then
    spAtlas_dispose(Self.FSpAtlas);
  if Self.FSpSkeletonJson <> nil then
    spSkeletonJson_dispose(Self.FSpSkeletonJson);
  if Self.FSpSkeletonData <> nil then
    spSkeletonData_dispose(Self.FSpSkeletonData);
  if Self.FSpAnimationStateData <> nil then
    spAnimationStateData_dispose(Self.FSpAnimationStateData);
  if Self.FSpSkeleton <> nil then
    spSkeleton_dispose(Self.FSpSkeleton);
  inherited;
end;

procedure TCastleSpine.LoadSpine(const AURL: String);
var
  SpPath,
  SpName,
  SkeletonFullPath,
  AtlasFullPath: String;
  MS: TMemoryStream;
  SS: TStringStream;
begin
  SpPath := ExtractFilePath(AURL);
  SpName := ExtractFileName(AURL);

  SkeletonFullPath := AURL;
  AtlasFullPath := SpPath + SpName + '.atlas';

  // Load atlas
  MS := Download(AtlasFullPath, [soForceMemoryStream]) as TMemoryStream;
  Self.FSpAtlas := spAtlas_create(MS.Memory, MS.Size, nil, nil);
  MS.Free;

  // Load skeleton data
  MS := Download(SkeletonFullPath, [soForceMemoryStream]) as TMemoryStream;
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(MS, MS.Size);
    Self.FSpSkeletonJson := spSkeletonJson_create(Self.FSpAtlas);
    Self.FSpSkeletonData := spSkeletonJson_readSkeletonData(Self.FSpSkeletonJson, PChar(SS.DataString + #0));
  finally
    SS.Free;
  end;
  MS.Free;

  // Prepare animation state data
  Self.FSpAnimationStateData := spAnimationStateData_create(Self.FSpSkeletonData);

  // Create skeleton
  Self.FSpSkeleton := spSkeleton_create(Self.FSpSkeletonData);
end;

procedure TCastleSpine.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited;
  Self.GLContextOpen;
  RemoveMe := rtNone;
  // TODO: Update
  if Self.FSpAnimationState <> nil then
  begin
    spAnimationState_update(Self.FSpAnimationState, SecondsPassed);
    spAnimationState_apply(Self.FSpAnimationState, Self.FSpSkeleton);
  end;
end;

procedure TCastleSpine.LocalRender(const Params: TRenderParams);
var
  PreviousProgram: TGLSLProgram;

  procedure RenderSkeleton(const Skeleton: PspSkeleton);
    procedure AddVertex(const X, Y, U, V: Single; const Color: TVector4; var Indx: Cardinal); inline;
    var
      P: PCastleSpineVertex;
    begin
      P := @SpineVertices[Indx];
      P^.Vertex := Vector2(X, Y);
      P^.TexCoord := Vector2(U, V);
      P^.Color := Color;
      Inc(Indx);
    end;

  var
    I, J, Indx: Integer;
    Attachment: PspAttachment;
    RegionAttachment: PSpRegionAttachment;
    MeshAttachment: PSpMeshAttachment;
    Slot: PspSlot;
    VertexCount: Cardinal;
    Image: TDrawableImage;
    Color: TVector4;
    V: PCastleSpineVertex;
  begin
    for J := 0 to Skeleton^.slotsCount - 1 do
    begin
      Slot := Skeleton^.drawOrder[J];
      Attachment := Slot^.Attachment;
      if Attachment = nil then continue;
      // TODO: Set blend mode
      case Slot^.data^.blendMode of
        SP_BLEND_MODE_ADDITIVE:
          begin
            glBlendFunc(GL_ONE, GL_ONE);
          end;
        else
          begin
            if Self.FSpAtlas^.pages^.pma <> 0 then
              glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
            else
              glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
          end;
      end;
      VertexCount := 0;
      if Attachment^.type_ = SP_ATTACHMENT_REGION then
      begin
        RegionAttachment := PSpRegionAttachment(Attachment);
        Color := Vector4(
          Skeleton^.color.r * Slot^.color.r * RegionAttachment^.color.r,
          Skeleton^.color.g * Slot^.color.g * RegionAttachment^.color.g,
          Skeleton^.color.b * Slot^.color.b * RegionAttachment^.color.b,
          Skeleton^.color.a * Slot^.color.a * RegionAttachment^.color.a
        );
        Image := TDrawableImage(RegionAttachment^.rendererObject);
        spRegionAttachment_computeWorldVertices(RegionAttachment, Slot^.bone, @WorldVerticesPositions[0], 0, 2);
        // Create 2 triangles
        AddVertex(WorldVerticesPositions[0], WorldVerticesPositions[1],
            RegionAttachment^.uvs[0], RegionAttachment^.uvs[1],
            Color, VertexCount);
        AddVertex(WorldVerticesPositions[2], WorldVerticesPositions[3],
            RegionAttachment^.uvs[2], RegionAttachment^.uvs[3],
            Color, VertexCount);
        AddVertex(WorldVerticesPositions[4], WorldVerticesPositions[5],
            RegionAttachment^.uvs[4], RegionAttachment^.uvs[5],
            Color, VertexCount);
        AddVertex(WorldVerticesPositions[4], WorldVerticesPositions[5],
            RegionAttachment^.uvs[4], RegionAttachment^.uvs[5],
            Color, VertexCount);
        AddVertex(WorldVerticesPositions[6], WorldVerticesPositions[7],
            RegionAttachment^.uvs[6], RegionAttachment^.uvs[7],
            Color, VertexCount);
        AddVertex(WorldVerticesPositions[0], WorldVerticesPositions[1],
            RegionAttachment^.uvs[0], RegionAttachment^.uvs[1],
            Color, VertexCount);
      end else
      if Attachment^.type_ = SP_ATTACHMENT_MESH then
      begin
        MeshAttachment := PspMeshAttachment(Attachment);
        if (MeshAttachment^.super.worldVerticesLength > High(WorldVerticesPositions)) then continue;
        Color := Vector4(
          Skeleton^.color.r * Slot^.color.r * MeshAttachment^.color.r,
          Skeleton^.color.g * Slot^.color.g * MeshAttachment^.color.g,
          Skeleton^.color.b * Slot^.color.b * MeshAttachment^.color.b,
          Skeleton^.color.a * Slot^.color.a * MeshAttachment^.color.a
        );
        Image := TDrawableImage(RegionAttachment^.rendererObject);
        spVertexAttachment_computeWorldVertices(@MeshAttachment^.super, Slot, 0, MeshAttachment^.Super.worldVerticesLength, @WorldVerticesPositions[0], 0, 2);
        // Create mesh
        for I := 0 to MeshAttachment^.trianglesCount - 1 do
        begin
          Indx := MeshAttachment^.triangles[I] shl 1;
          AddVertex(WorldVerticesPositions[Indx], WorldVerticesPositions[Indx + 1],
              RegionAttachment^.uvs[Indx], RegionAttachment^.uvs[Indx + 1],
              Color, VertexCount);
        end;
      end;
      // Render the result
      glActiveTexture(GL_TEXTURE0);
      glBindTexture(GL_TEXTURE_2D, Image.Texture);
      glBegin(GL_TRIANGLES);
        for I := 0 to VertexCount - 1 do
        begin
          V := @SpineVertices[I];
          glColor4f(V^.Color.X, V^.Color.Y, V^.Color.Z, V^.Color.W);
          glTexCoord2f(V^.TexCoord.X, V^.TexCoord.Y);
          glVertex2f(V^.Vertex.X, V^.Vertex.Y);
        end;
      glEnd();
    end;
  end;

begin
  inherited;
  if not Self.FIsGLContextInitialized then
    Exit;
  PreviousProgram := RenderContext.CurrentProgram;

  glEnable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glDepthMask(GL_TRUE);
  // TODO: Update world transform and render skeleton
  spAnimationState_updateWorldTransform(FSpSkeleton);
  RenderSkeleton(Self.FSpSkeleton);

  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);

  PreviousProgram.Enable;
end;

initialization
  RegisterSerializableComponent(TCastleSpine, 'Spine');

end.
