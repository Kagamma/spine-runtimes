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
{$macro on}
{$define nl:=+ LineEnding +}

{$ifdef ANDROID}{$define GLES}{$endif}
{$ifdef iOS}{$define GLES}{$endif}

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
    FIsNeedRefreshAnimation: Boolean;
    FParameters: TPlayAnimationParameters;
    FIsGLContextInitialized: Boolean;
    FspAtlas: PspAtlas;
    FspSkeletonJson: PspSkeletonJson;
    FspSkeletonData: PspSkeletonData;
    FspAnimationStateData: PspAnimationStateData;
    FspSkeleton: PspSkeleton;
    FspAnimationState: PspAnimationState;
    FIsNeedRefresh: Boolean;
    FPreviousAnimation: String;
    FIsAnimationPlaying: Boolean;
    FAutoAnimation: String;
    FAutoAnimationLoop: Boolean;
    procedure Cleanup;
    procedure GLContextOpen;
    procedure InternalLoadSpine;
    procedure InternalPlayAnimation;
    procedure SetAutoAnimation(S: String);
    procedure SetAutoAnimationLoop(V: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadSpine(const AURL: String);
    procedure GLContextClose; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure LocalRender(const Params: TRenderParams); override;
    function PlayAnimation(const AnimationName: string; const Loop: boolean; const Forward: boolean = true): boolean; overload;
    function PlayAnimation(const Parameters: TPlayAnimationParameters): boolean; overload;
    procedure StopAnimation;
  published
    property URL: String read FURL write LoadSpine;
    property AutoAnimation: String read FAutoAnimation write SetAutoAnimation;
    property AutoAnimationLoop: Boolean read FAutoAnimationLoop write SetAutoAnimationLoop default true;
  end;

implementation

const
  VertexShaderSource =
{$ifdef GLES}
'#version 300 es'nl
{$else}
'#version 330'nl
{$endif}

'layout(location = 0) in vec2 inVertex;'nl
'layout(location = 1) in vec2 inTexCoord;'nl
'layout(location = 2) in vec4 inColor;'nl

'out vec2 fragTexCoord;'nl
'out vec4 fragColor;'nl

'uniform mat4 mvpMatrix;'nl

'void main() {'nl
'  fragTexCoord = inTexCoord;'nl
'  fragColor = inColor;'nl
'  gl_Position = mvpMatrix * vec4(inVertex, 0.0, 1.0);'nl
'}';

  FragmentShaderSource: String =
{$ifdef GLES}
'#version 300 es'nl
{$else}
'#version 330'nl
{$endif}
'precision lowp float;'nl

'in vec2 fragTexCoord;'nl
'in vec4 fragColor;'nl

'out vec4 outColor;'nl

'uniform sampler2D baseColor;'nl

'void main() {'nl
'  outColor = texture(baseColor, fragTexCoord) * fragColor;'nl
'}';

var
  WorldVerticesPositions: array[0..(16384 * 3 - 1)] of Single;
  SpineVertices: array[0..(High(WorldVerticesPositions) div 3) - 1] of TCastleSpineVertex;
  RenderProgram: TGLSLProgram;
  VAO, VBO: GLuint;

{ Provide loader functions for Spine }
procedure LoaderLoad(FileName: PChar; var Data: Pointer; var Size: LongWord); cdecl;
var
  S: String;
  MS: TMemoryStream;
begin
  try
    S := FileName;
    MS := Download(S, [soForceMemoryStream]) as TMemoryStream;
    // Data is managed by spine-c, so we call spine-c mem functions instead
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
  if Spine_Load then
  begin
    Spine_Loader_RegisterLoadRoutine(@LoaderLoad);
    Spine_Loader_RegisterLoadTextureRoutine(@LoaderLoadTexture);
    Spine_Loader_RegisterFreeTextureRoutine(@LoaderFreeTexture);
  end;
  if RenderProgram = nil then
  begin
    RenderProgram := TGLSLProgram.Create;
    RenderProgram.AttachVertexShader(VertexShaderSource);
    RenderProgram.AttachFragmentShader(FragmentShaderSource);
    RenderProgram.Link;
  end;
  if VAO = 0 then
  begin
    glGenVertexArrays(1, @VAO);
    glGenBuffers(1, @VBO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, Length(SpineVertices) * SizeOf(TCastleSpineVertex), @SpineVertices[0], GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(0));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(8));
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(16));
    glBindVertexArray(0);
  end;
  Self.FIsGLContextInitialized := True;
end;

procedure TCastleSpine.GLContextClose;
begin
  if Self.FIsGLContextInitialized then
  begin
    if VAO <> 0 then
    begin
      glDeleteBuffers(1, @VBO);
      glDeleteVertexArrays(1, @VAO);
      VAO := 0;
    end;
    Self.FIsGLContextInitialized := False;
  end;
  inherited;
end;

procedure TCastleSpine.InternalLoadSpine;
var
  Path: String;
  SkeletonFullPath,
  AtlasFullPath: String;
  MS: TMemoryStream;
  SS: TStringStream;
  I: Integer;
begin
  Self.Cleanup;

  if Self.FURL = '' then
  begin
    Self.FIsNeedRefresh := False;
    Exit;
  end;

  Path := ExtractFilePath(Self.FURL);
  SkeletonFullPath := Self.FURL;
  AtlasFullPath := Path + StringReplace(ExtractFileName(Self.FURL), ExtractFileExt(Self.FURL), '', [rfReplaceAll]) + '.atlas';

  // Load atlas
  MS := Download(AtlasFullPath, [soForceMemoryStream]) as TMemoryStream;
  Self.FspAtlas := spAtlas_create(MS.Memory, MS.Size, PChar(Path), nil);
  Self.FspAtlas := spAtlas_create(MS.Memory, MS.Size, PChar(Path), nil);
  MS.Free;

  // Load skeleton data
  MS := Download(SkeletonFullPath, [soForceMemoryStream]) as TMemoryStream;
  SS := TStringStream.Create('');
  try
    SS.CopyFrom(MS, MS.Size);
    Self.FspSkeletonJson := spSkeletonJson_create(Self.FspAtlas);
    Self.FspSkeletonData := spSkeletonJson_readSkeletonData(Self.FspSkeletonJson, PChar(SS.DataString));
  finally
    SS.Free;
  end;
  MS.Free;

  // Prepare animation state data
  Self.FspAnimationStateData := spAnimationStateData_create(Self.FspSkeletonData);
  Self.FspAnimationState := spAnimationState_create(Self.FspAnimationStateData);

  // Create skeleton
  Self.FspSkeleton := spSkeleton_create(Self.FspSkeletonData);

  // Load animation list
  Self.AnimationsList.Clear;
  for I := 0 to Self.FspSkeletonData^.animationsCount - 1 do
  begin
    Self.AnimationsList.Add(Self.FspSkeletonData^.animations[I]^.name);
  end;

  Self.FIsNeedRefresh := False;
end;

procedure TCastleSpine.Cleanup;
begin
  if Self.FspAnimationState <> nil then
    spAnimationState_dispose(Self.FspAnimationState);
  if Self.FspAtlas <> nil then
    spAtlas_dispose(Self.FspAtlas);
  if Self.FspSkeletonJson <> nil then
    spSkeletonJson_dispose(Self.FspSkeletonJson);
  if Self.FspSkeletonData <> nil then
    spSkeletonData_dispose(Self.FspSkeletonData);
  if Self.FspAnimationStateData <> nil then
    spAnimationStateData_dispose(Self.FspAnimationStateData);
  if Self.FspSkeleton <> nil then
    spSkeleton_dispose(Self.FspSkeleton);
  Self.FspAtlas := nil;
  Self.FspSkeletonJson := nil;
  Self.FspSkeletonData := nil;
  Self.FspAnimationStateData := nil;
  Self.FspSkeleton := nil;
  Self.FspAnimationState := nil;
end;

procedure TCastleSpine.SetAutoAnimation(S: String);
begin
  Self.FAutoAnimation := S;
  if Self.FAutoAnimation <> '' then
    Self.PlayAnimation(Self.FAutoAnimation, Self.FAutoAnimationLoop)
  else
    Self.StopAnimation;
end;

procedure TCastleSpine.SetAutoAnimationLoop(V: Boolean);
begin
  Self.FAutoAnimationLoop := V;
  if Self.FAutoAnimation <> '' then
    Self.PlayAnimation(Self.FAutoAnimation, Self.FAutoAnimationLoop);
end;

constructor TCastleSpine.Create(AOwner: TComponent);
begin
  inherited;
  Self.FParameters := TPlayAnimationParameters.Create;
  Self.FAutoAnimationLoop := True;
end;

destructor TCastleSpine.Destroy;
begin
  Self.Cleanup;
  Self.FParameters.Free;
  inherited;
end;

procedure TCastleSpine.LoadSpine(const AURL: String);
begin
  Self.FURL := AURL;
  Self.FIsNeedRefresh := True;
end;

procedure TCastleSpine.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  F: Single;
begin
  inherited;
  Self.GLContextOpen;

  if not Self.Exists then
    Exit;

  if Self.FIsNeedRefresh then
    Self.InternalLoadSpine;
  if Self.FIsNeedRefreshAnimation then
    Self.InternalPlayAnimation;

  RemoveMe := rtNone;
  // Update
  if Self.FIsGLContextInitialized and (Self.FspAnimationState <> nil) then
  begin
    if Self.TimePlaying then
      F := SecondsPassed * Self.TimePlayingSpeed
    else
      F := SecondsPassed;
    if Self.FIsAnimationPlaying and Self.ProcessEvents then
    begin
      if (Self.AnimateOnlyWhenVisible and Self.Visible) or (not Self.AnimateOnlyWhenVisible) then
        spAnimationState_update(Self.FspAnimationState, F);
    end;
    spAnimationState_apply(Self.FspAnimationState, Self.FspSkeleton);
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
    RegionAttachment: PspRegionAttachment;
    MeshAttachment: PspMeshAttachment;
    Slot: PspSlot;
    VertexCount: Cardinal;
    PreviousImage: TDrawableImage = nil;
    Image: TDrawableImage;
    PreviousBlendMode: Integer = -1;
    Color: TVector4;
    V: PCastleSpineVertex;
  begin
    VertexCount := 0;
    for J := 0 to Skeleton^.slotsCount - 1 do
    begin
      Slot := Skeleton^.drawOrder[J];
      Attachment := Slot^.Attachment;
      if Attachment <> nil then
      begin
        // Blend mode
        case Slot^.data^.blendMode of
          SP_BLEND_MODE_ADDITIVE:
            begin
              glBlendFunc(GL_ONE, GL_ONE);
            end;
          else
            begin
              if Self.FspAtlas^.pages^.pma <> 0 then
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
              else
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end;
        end;
        if Attachment^.type_ = SP_ATTACHMENT_REGION then
        begin
          RegionAttachment := PspRegionAttachment(Attachment);
          Color := Vector4(
            Skeleton^.color.r * Slot^.color.r * RegionAttachment^.color.r,
            Skeleton^.color.g * Slot^.color.g * RegionAttachment^.color.g,
            Skeleton^.color.b * Slot^.color.b * RegionAttachment^.color.b,
            Skeleton^.color.a * Slot^.color.a * RegionAttachment^.color.a
          );
          Image := TDrawableImage(PspAtlasRegion(RegionAttachment^.rendererObject)^.page^.rendererObject);
          spRegionAttachment_computeWorldVertices(RegionAttachment, Slot^.bone, @WorldVerticesPositions[0], 0, 2);
          // Create 2 triangles
          AddVertex(WorldVerticesPositions[0], WorldVerticesPositions[1],
              RegionAttachment^.uvs[0], 1 - RegionAttachment^.uvs[1],
              Color, VertexCount);
          AddVertex(WorldVerticesPositions[2], WorldVerticesPositions[3],
              RegionAttachment^.uvs[2], 1 - RegionAttachment^.uvs[3],
              Color, VertexCount);
          AddVertex(WorldVerticesPositions[4], WorldVerticesPositions[5],
              RegionAttachment^.uvs[4], 1 - RegionAttachment^.uvs[5],
              Color, VertexCount);
          AddVertex(WorldVerticesPositions[4], WorldVerticesPositions[5],
              RegionAttachment^.uvs[4], 1 - RegionAttachment^.uvs[5],
              Color, VertexCount);
          AddVertex(WorldVerticesPositions[6], WorldVerticesPositions[7],
              RegionAttachment^.uvs[6], 1 - RegionAttachment^.uvs[7],
              Color, VertexCount);
          AddVertex(WorldVerticesPositions[0], WorldVerticesPositions[1],
              RegionAttachment^.uvs[0], 1 - RegionAttachment^.uvs[1],
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
          Image := TDrawableImage(PspAtlasRegion(MeshAttachment^.rendererObject)^.page^.rendererObject);
          spVertexAttachment_computeWorldVertices(@MeshAttachment^.super, Slot, 0, MeshAttachment^.Super.worldVerticesLength, @WorldVerticesPositions[0], 0, 2);
          // Create mesh
          for I := 0 to MeshAttachment^.trianglesCount - 1 do
          begin
            Indx := MeshAttachment^.triangles[I] shl 1;
            AddVertex(WorldVerticesPositions[Indx], WorldVerticesPositions[Indx + 1],
                MeshAttachment^.uvs[Indx], 1 - MeshAttachment^.uvs[Indx + 1],
                Color, VertexCount);
          end;
        end;
        if J = 0 then
        begin
          PreviousImage := Image;
          PreviousBlendMode := Integer(Slot^.data^.blendMode);
        end;
      end;
      if (PreviousBlendMode <> Integer(Slot^.data^.blendMode)) or (PreviousImage <> Image) or
        ((J = Skeleton^.slotsCount - 1) and (VertexCount > 0)) then
      begin
        // Render result
        glBindTexture(GL_TEXTURE_2D, Image.Texture);

        glBindBuffer(GL_ARRAY_BUFFER, VBO);
        glBufferSubData(GL_ARRAY_BUFFER, 0, VertexCount * SizeOf(TCastleSpineVertex), @SpineVertices[0]);
        glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBindVertexArray(VAO);
        glDrawArrays(GL_TRIANGLES, 0, VertexCount);
        glBindVertexArray(0);
        VertexCount := 0;
        PreviousImage := Image;
        PreviousBlendMode := Integer(Slot^.data^.blendMode);
        Inc(Params.Statistics.ShapesVisible, 1);
        Inc(Params.Statistics.ShapesRendered, 1);
      end;
    end;
    glBindTexture(GL_TEXTURE_2D, 0);
  end;

begin
  inherited;
  if Self.FspAnimationState = nil then
    Exit;
  if not Self.FIsGLContextInitialized then
    Exit;
  if (not Self.Visible) or (not Self.Exists) or Params.InShadow or (not Params.Transparent) or (Params.StencilTest > 0) then
    Exit;
  PreviousProgram := RenderContext.CurrentProgram;
  RenderProgram.Enable;

  RenderProgram.Uniform('mvpMatrix').SetValue(RenderContext.ProjectionMatrix * Params.RenderingCamera.Matrix * Params.Transform^);

  glEnable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glDepthMask(GL_FALSE);
  glActiveTexture(GL_TEXTURE0);

  spSkeleton_updateWorldTransform(FspSkeleton);
  RenderSkeleton(Self.FspSkeleton);

  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_TRUE);

  PreviousProgram.Enable;
end;

function TCastleSpine.PlayAnimation(const Parameters: TPlayAnimationParameters): boolean;
begin
  Self.FParameters.Name := Parameters.Name;
  Self.FParameters.Loop := Parameters.Loop;
  Self.FParameters.Forward := Parameters.Forward;
  Self.FParameters.TransitionDuration := Parameters.TransitionDuration;
  Self.FIsAnimationPlaying := True;
  Self.FIsNeedRefreshAnimation := True;
  Result := True;
end;

function TCastleSpine.PlayAnimation(const AnimationName: string; const Loop: boolean; const Forward: boolean): boolean;
begin
  Self.FParameters.Name := AnimationName;
  Self.FParameters.Loop := Loop;
  Self.FParameters.Forward := Forward;
  Self.FParameters.TransitionDuration := Self.DefaultAnimationTransition;
  Self.FIsAnimationPlaying := True;
  Self.FIsNeedRefreshAnimation := True;
  Result := True;
end;

procedure TCastleSpine.StopAnimation;
begin
  Self.FIsAnimationPlaying := False;
end;

procedure TCastleSpine.InternalPlayAnimation;
begin
  if Self.FspAnimationState = nil then Exit;
  if (Self.FPreviousAnimation <> '') and (Self.FPreviousAnimation <> Self.FParameters.Name) then
  begin
    spAnimationStateData_setMixByName(Self.FspAnimationStateData, PChar(Self.FPreviousAnimation), PChar(Self.FParameters.Name), Self.FParameters.TransitionDuration);
  end;
  spAnimationState_setAnimationByName(Self.FspAnimationState, 0, PChar(Self.FParameters.Name), Self.FParameters.Loop);
  Self.FPreviousAnimation := Self.FParameters.Name;
  Self.FIsNeedRefreshAnimation := False;
end;

initialization
  RegisterSerializableComponent(TCastleSpine, 'Spine');

end.
