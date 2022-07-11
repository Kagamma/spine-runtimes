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
  Classes, SysUtils, Generics.Collections, fpjsonrtti, Spine, strutils,
  {$ifdef GLES}
  CastleGLES,
  {$else}
  GL, GLExt,
  {$endif}
  {$ifdef CASTLE_DESIGN_MODE}
  PropEdits, CastlePropEdits, CastleDebugTransform, Forms, Controls, Graphics, Dialogs,
  ButtonPanel, StdCtrls, ExtCtrls, CastleInternalExposeTransformsDialog,
  {$endif}
  CastleVectors, CastleSceneCore, CastleApplicationProperties, CastleTransform, CastleComponentSerialize,
  CastleBoxes, CastleUtils, CastleLog, CastleRenderContext, CastleGLShaders, CastleDownload, CastleURIUtils,
  CastleGLImages, X3DNodes, CastleColors, CastleClassUtils, CastleBehaviors;

type
  TCastleSpineEvent = record
    State: PspAnimationState;
    Typ: TSpEventType;
    Entry: PspTrackEntry;
    Event: PspEvent;
  end;

  TCastleSpineEventNotify = procedure(const Event: TCastleSpineEvent) of object;

  PCastleSpineVertex = ^TCastleSpineVertex;
  TCastleSpineVertex = packed record
    Vertex: TVector2;
    TexCoord: TVector2;
    Color: TVector4;
  end;

  TCastleSpineControlBone = record
    Bone: PspBone;
    X, Y, Rotation: Single;
  end;
  TCastleSpineControlBoneList = specialize TList<TCastleSpineControlBone>;

  PCastleSpineData = ^TCastleSpineData;
  TCastleSpineData = record
    Atlas: PspAtlas;
    SkeletonJson: PspSkeletonJson;
    SkeletonData: PspSkeletonData;
    AnimationStateData: PspAnimationStateData;
  end;

  TCastleSpineDataCacheBase = specialize TDictionary<String, PCastleSpineData>;
  TCastleSpineDataCache = class(TCastleSpineDataCacheBase)
  public
    // Clear the cache
    procedure Clear; override;
  end;

  TCastleSpineTransformBehavior = class(TCastleBehavior)
  private
    FControlBone: Boolean;
    FOldTranslation: TVector3;
    FOldRotation: Single;
    FOldData: TCastleSpineControlBone;
    FBone: PspBone;
    FBoneDefault: PspBone;
  public
    {$ifdef CASTLE_DESIGN_MODE}
    function PropertySections(const PropertyName: String): TPropertySections; override;
    {$endif}
    procedure SetControlBone(const V: Boolean);
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    property Bone: PspBone read FBone write FBone;
    property BoneDefault: PspBone read FBoneDefault write FBoneDefault;
  published
    property ControlBone: Boolean read FControlBone write SetControlBone default False;
  end;

  TCastleSpine = class(TCastleSceneCore)
  strict private
    VBO: GLuint; // Maybe all instances could share the same VBO?
    FURL: String;
    FIsNeedRefreshAnimation: Boolean;
    FParameters: TPlayAnimationParameters;
    FTrack: Integer;
    FIsGLContextInitialized: Boolean;
    FspSkeleton: PspSkeleton;
    FspSkeletonDefault: array of TspBone;
    FspAnimationState: PspAnimationState;
    FspSkeletonBounds: PspSkeletonBounds;
    FspClipper: PspSkeletonClipping;
    FEnableFog: Boolean;
    FIsNeedRefreshBones: Boolean;
    FIsNeedRefresh: Boolean;
    FPreviousAnimation: String;
    FIsAnimationPlaying: Boolean;
    FAutoAnimation: String;
    FAutoAnimationLoop: Boolean;
    FSpineData: PCastleSpineData;
    FDistanceCulling: Single;
    FSecondsPassedAcc: Single; // Used by AnimationSkipTicks
    FTicks: Integer; // Used by AnimationSkipTicks
    FSmoothTexture: Boolean;
    FColor: TVector4;
    FExposeTransforms: TStrings;
    FExposeTransformsPrefix: String;
    FColorPersistent: TCastleColorPersistent;
    FOnEventNotify: TCastleSpineEventNotify; // Used by Spine's events
    FControlBoneList: TCastleSpineControlBoneList;
    { Cleanup Spine resource associate with this instance }
    procedure Cleanup;
    procedure InternalExposeTransformsChange;
    procedure ExposeTransformsChange(Sender: TObject);
    procedure GLContextOpen;
    procedure InternalLoadSpine;
    procedure InternalPlayAnimation;
    procedure SetAutoAnimation(const S: String);
    procedure SetAutoAnimationLoop(const V: Boolean);
    procedure SetColorForPersistent(const AValue: TVector4);
    procedure SetExposeTransforms(const Value: TStrings);
    procedure SetExposeTransformsPrefix(const S: String);
    function GetColorForPersistent: TVector4;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    {$ifdef CASTLE_DESIGN_MODE}
    function PropertySections(const PropertyName: String): TPropertySections; override;
    {$endif}
    procedure LoadSpine(const AURL: String);
    procedure GLContextClose; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure LocalRender(const Params: TRenderParams); override;
    function LocalBoundingBox: TBox3D; override;
    { Similar to PlayAnimation. The Track parameter tell Spine runtime which track we play the animation, allows to mix multiple animations }
    function PlayAnimation(const AnimationName: string; const Loop: boolean; const Forward: boolean = true; const Track: Integer = 0): boolean; overload;
    function PlayAnimation(const Parameters: TPlayAnimationParameters): boolean; overload;
    { Similar to StopAnimation. The Track parameter tell Spine runtime which track we stop the animation. If Track = -1, then we stop all animations }
    procedure StopAnimation(const Track: Integer = -1); overload;
    property Color: TVector4 read FColor write FColor;
    property Skeleton: PspSkeleton read FspSkeleton;
    property ControlBoneList: TCastleSpineControlBoneList read FControlBoneList;
  published
    property URL: String read FURL write LoadSpine;
    property AutoAnimation: String read FAutoAnimation write SetAutoAnimation;
    property AutoAnimationLoop: Boolean read FAutoAnimationLoop write SetAutoAnimationLoop default true;
    property EnableFog: Boolean read FEnableFog write FEnableFog default False;
    property ColorPersistent: TCastleColorPersistent read FColorPersistent;
    property SmoothTexture: Boolean read FSmoothTexture write FSmoothTexture default True;
    property DistanceCulling: Single read FDistanceCulling write FDistanceCulling default 0;
    property ExposeTransforms: TStrings read FExposeTransforms write SetExposeTransforms;
    property ExposeTransformsPrefix: String read FExposeTransformsPrefix write SetExposeTransformsPrefix;
    property OnEventNotify: TCastleSpineEventNotify read FOnEventNotify write FOnEventNotify;
  end;

var
  SpineDataCache: TCastleSpineDataCache;

implementation

const
  VertexShaderSource =
'attribute vec2 inVertex;'nl
'attribute vec2 inTexCoord;'nl
'attribute vec4 inColor;'nl

'varying vec2 fragTexCoord;'nl
'varying vec4 fragColor;'nl
'varying float fragFogCoord;'nl

'uniform mat4 mvMatrix;'nl
'uniform mat4 pMatrix;'nl

'void main() {'nl
'  fragTexCoord = inTexCoord;'nl
'  fragColor = inColor;'nl
'  vec4 p = mvMatrix * vec4(inVertex, 0.0, 1.0);'nl
'  fragFogCoord = abs(p.z / p.w);'nl
'  gl_Position = pMatrix * p;'nl
'}';

  FragmentShaderSource: String =
'varying vec2 fragTexCoord;'nl
'varying vec4 fragColor;'nl
'varying float fragFogCoord;'nl

'uniform sampler2D baseColor;'nl
'uniform int fogEnable;'nl
'uniform float fogEnd;'nl
'uniform vec3 fogColor;'nl
'uniform vec4 color;'nl

'void main() {'nl
'  gl_FragColor = texture2D(baseColor, fragTexCoord) * fragColor * color;'nl
'  if (fogEnable == 1) {'nl
'    float fogFactor = (fogEnd - fragFogCoord) / fogEnd;'nl
'    gl_FragColor.rgb = mix(fogColor, gl_FragColor.rgb, clamp(fogFactor, 0.0, 1.0));'nl
'  }'nl
'}';

{$ifdef CASTLE_DESIGN_MODE}
type
  TExposeTransformsPropertyEditor = class(TStringsPropertyEditor)
  public
    procedure Edit; override;
  end;
{$endif}

var
  WorldVerticesPositions: array[0..(16384 * 3 - 1)] of Single;
  SpineVertices: array[0..(High(WorldVerticesPositions) div 3) - 1] of TCastleSpineVertex;
  RenderProgram: TGLSLProgram;
  RegionIndices: array[0..5] of Word = (0, 1, 2, 2, 3, 0);
  CurrentSpineInstance: TCastleSpine;

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

function CreateColorPersistent(const G: TGetVector4Event; const S: TSetVector4Event; const ADefaultValue: TVector4): TCastleColorPersistent;
begin
  Result := TCastleColorPersistent.Create;
  Result.InternalGetValue := G;
  Result.InternalSetValue := S;
  Result.InternalDefaultValue := ADefaultValue;
end;

{ Naive implementation of util function that takes a bone name and convert to valid component name }
function ValidName(const S: String): String;
begin
  Result := StringsReplace(S, [' ', '-'], ['_', '_'], [rfReplaceAll]);
end;

{ Trigger when an Spine event is fired. CurrentSpineInstance is the instance where the event belong to }
procedure EventListener(State: PspAnimationState; Typ: TSpEventType; Entry: PspTrackEntry; Event: PspEvent); cdecl;
var
  E: TCastleSpineEvent;
begin
  if (CurrentSpineInstance <> nil) and (CurrentSpineInstance.OnEventNotify <> nil) then
  begin
    E.State := State;
    E.Typ := Typ;
    E.Entry := Entry;
    E.Event := Event;
    CurrentSpineInstance.OnEventNotify(E);
  end;
end;

{ ----- TCastleSpineTransformBehavior ----- }

{$ifdef CASTLE_DESIGN_MODE}
function TCastleSpineTransformBehavior.PropertySections(
  const PropertyName: String): TPropertySections;
begin
  if (PropertyName = 'ControlBone') then
    Result := [psBasic]
  else
    Result := inherited PropertySections(PropertyName);
end;
{$endif}

procedure TCastleSpineTransformBehavior.SetControlBone(const V: Boolean);
begin
  Self.FControlBone := V;
  Self.FOldTranslation := TVector3.Zero;
end;

procedure TCastleSpineTransformBehavior.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  V: TVector4;
  D: TCastleSpineControlBone;

  procedure UpdateParentPosition; inline;
  begin
    Self.Parent.Translation := Vector3(Self.Bone^.worldX, Self.Bone^.worldY, 0);
    Self.Parent.Rotation := Vector4(0, 0, 1, spBone_getWorldRotationX(Self.Bone) * 0.017453);
    Self.Parent.Scale := Vector3(spBone_getWorldScaleX(Bone), spBone_getWorldScaleY(Bone), 1);
  end;

begin
  inherited;
  if Bone = nil then Exit;
  if not Self.FControlBone then
  begin
    UpdateParentPosition;
  end else
  begin
    if (Self.FOldTranslation.X <> Self.Parent.Translation.X) or (Self.FOldTranslation.Y <> Self.Parent.Translation.Y) or (Self.FOldRotation <> Self.Parent.Rotation.W) then
    begin
      Bone^ := Self.FBoneDefault^;
      // TODO: Correctly handle rotation
      // TODO: Currently this expects "world", or "root", locate at (0,0)
      // TODO: Only IKs at root work correctly at the moment
      V := Self.Parent.Parent.WorldInverseTransform * (Self.Parent.WorldTransform * Vector4(Self.Parent.Translation, 1.0)) * 0.5;
      spBone_worldToLocal(Bone, V.X, V.Y, @D.X, @D.Y);
      D.Rotation := Self.Parent.Rotation.W * 57.29578;
      D.Bone := Bone;
      Self.FOldData := D;
    end;
    if Self.FOldData.Bone <> nil then
      TCastleSpine(Self.Parent.Parent).ControlBoneList.Add(Self.FOldData);
  end;
  Self.FOldTranslation := Self.Parent.Translation;
  Self.FOldRotation := Self.Parent.Rotation.W;
end;

{ ----- TExposeTransformsPropertyEditor ----- }

{$ifdef CASTLE_DESIGN_MODE}
procedure TExposeTransformsPropertyEditor.Edit;
var
  DialogSelection: TExposeTransformSelection;
  D: TExposeTransformsDialog;
  ValueStrings, SelectionList: TStrings;
  S: String;
  SelItem: TExposeTransformSelectionItem;
  Skeleton: PspSkeleton;
  Scene: TCastleSpine;
  Item: TExposeTransformSelectionItem;
  I: Integer;
begin
  D := TExposeTransformsDialog.Create(Application);
  try
    Scene := GetComponent(0) as TCastleSpine;
    Skeleton := Scene.Skeleton;
    D.Caption := 'Edit ' + Scene.Name + '.ExposeTransforms';

    DialogSelection := D.Selection;
    DialogSelection.Clear;

    // add to D.Selection all possible transforms from the scene
    if Skeleton <> nil then
      for I := 0 to Skeleton^.bonesCount - 1 do
      begin
        if DialogSelection.FindName(Skeleton^.bones[I]^.data^.name) = nil then
        begin
          Item := TExposeTransformSelectionItem.Create;
          Item.Name := Skeleton^.bones[I]^.data^.name;
          Item.ExistsInScene := true;
          Item.Selected := false; // may be changed to true later
          DialogSelection.Add(Item);
        end;
      end;

    // add/update in D.Selection all currently selected transforms
    ValueStrings := TStrings(GetObjectValue);
    for S in ValueStrings do
      if S <> '' then
      begin
        SelItem := D.Selection.FindName(S);
        if SelItem = nil then
        begin
          SelItem := TExposeTransformSelectionItem.Create;
          SelItem.Name := S;
          SelItem.ExistsInScene := false;
          DialogSelection.Add(SelItem);
        end;
        SelItem.Selected := true
      end;

    D.UpdateSelectionUi;
    if D.ShowModal = mrOK then
    begin
      SelectionList := DialogSelection.ToList;
      try
        SetPtrValue(SelectionList);
      finally FreeAndNil(SelectionList) end;
    end;
    Modified;
  finally FreeAndNil(D) end;
end;
{$endif}

{ ----- TCastleSpineDataCache ----- }

procedure TCastleSpineDataCache.Clear;
var
  Key: String;
  SpineData: PCastleSpineData;
begin
  for Key in Self.Keys do
  begin
    SpineData := Self[Key];
    spAtlas_dispose(SpineData^.Atlas);
    spSkeletonJson_dispose(SpineData^.SkeletonJson);
    spSkeletonData_dispose(SpineData^.SkeletonData);
    spAnimationStateData_dispose(SpineData^.AnimationStateData);
    Dispose(SpineData);
  end;
  inherited;
end;

{ ----- TCastleSpine ----- }

procedure TCastleSpine.GLContextOpen;
begin
  if not ApplicationProperties.IsGLContextOpen then Exit;
  if Self.FIsGLContextInitialized then Exit;
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
  if VBO = 0 then
  begin
    glGenBuffers(1, @VBO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, Length(SpineVertices) * SizeOf(TCastleSpineVertex), @SpineVertices[0], GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
  end;
  Self.FIsGLContextInitialized := True;
end;

procedure TCastleSpine.GLContextClose;
begin
  if Self.FIsGLContextInitialized then
  begin
    if VBO <> 0 then
    begin
      glDeleteBuffers(1, @VBO);
      VBO := 0;
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
  SpineData: PCastleSpineData;
  I: Integer;
begin
  Self.Cleanup;

  if Self.FURL = '' then
  begin
    Self.FIsNeedRefresh := False;
    Exit;
  end;
  CurrentSpineInstance := Self;

  {$ifdef CASTLE_DESIGN_MODE}
  SpineDataCache.Clear; // We don't cache spine data in castle-editor
  {$endif}

  if not SpineDataCache.ContainsKey(Self.FURL) then
  begin
    New(SpineData);

    Path := ExtractFilePath(Self.FURL);
    SkeletonFullPath := Self.FURL;
    AtlasFullPath := Path + StringReplace(ExtractFileName(Self.FURL), ExtractFileExt(Self.FURL), '', [rfReplaceAll]) + '.atlas';

    // Load atlas
    MS := Download(AtlasFullPath, [soForceMemoryStream]) as TMemoryStream;
    SpineData^.Atlas := spAtlas_create(MS.Memory, MS.Size, PChar(Path), nil);
    MS.Free;

    // Load skeleton data
    MS := Download(SkeletonFullPath, [soForceMemoryStream]) as TMemoryStream;
    SS := TStringStream.Create('');
    try
      SS.CopyFrom(MS, MS.Size);
      SpineData^.SkeletonJson := spSkeletonJson_create(SpineData^.Atlas);
      SpineData^.SkeletonData := spSkeletonJson_readSkeletonData(SpineData^.SkeletonJson, PChar(SS.DataString));
    finally
      SS.Free;
    end;
    MS.Free;

    // Prepare animation state data
    SpineData^.AnimationStateData := spAnimationStateData_create(SpineData^.SkeletonData);
  end else
    SpineData := SpineDataCache[Self.FURL];

  // Create animation state
  Self.FspAnimationState := spAnimationState_create(SpineData^.AnimationStateData);
  Self.FspAnimationState^.listener := @EventListener;

  // Create skeleton
  Self.FspSkeleton := spSkeleton_create(SpineData^.SkeletonData);
  spSkeleton_setToSetupPose(Self.FspSkeleton);
  SetLength(Self.FspSkeletonDefault, Self.FspSkeleton^.bonesCount);
  for I := 0 to Self.FspSkeleton^.bonesCount - 1 do
    Self.FspSkeletonDefault[I] := Self.FspSkeleton^.bones[I]^;

  // Create boundingbox
  Self.FspSkeletonBounds := spSkeletonBounds_create();
  spSkeletonBounds_update(Self.FspSkeletonBounds, Self.FspSkeleton, True);

  // Create clipper
  Self.FspClipper := spSkeletonClipping_create();

  // Load animation list
  Self.AnimationsList.Clear;
  for I := 0 to SpineData^.SkeletonData^.animationsCount - 1 do
  begin
    Self.AnimationsList.Add(SpineData^.SkeletonData^.animations[I]^.name);
    // Auto play animation
    if SpineData^.SkeletonData^.animations[I]^.name = Self.FAutoAnimation then
      Self.AutoAnimation := Self.AutoAnimation;
  end;

  // Expose bone list
  Self.ExposeTransformsChange(nil);

  Self.FIsNeedRefresh := False;
  Self.FSpineData := SpineData;
  CurrentSpineInstance := nil;
end;

procedure TCastleSpine.Cleanup;
begin
  CurrentSpineInstance := Self;
  if Self.FspAnimationState <> nil then
    spAnimationState_dispose(Self.FspAnimationState);
  if Self.FspSkeleton <> nil then
    spSkeleton_dispose(Self.FspSkeleton);
  if Self.FspSkeletonBounds <> nil then
    spSkeletonBounds_dispose(Self.FspSkeletonBounds);
  if Self.FspClipper <> nil then
    spSkeletonClipping_dispose(Self.FspClipper);
  Self.FspSkeleton := nil;
  Self.FspAnimationState := nil;
  Self.FspSkeletonBounds := nil;
  Self.FspClipper := nil;
  CurrentSpineInstance := nil;
end;

procedure TCastleSpine.ExposeTransformsChange(Sender: TObject);
begin
  Self.FIsNeedRefreshBones := True;
end;

procedure TCastleSpine.InternalExposeTransformsChange;
var
  T: TCastleTransform;
  B: TCastleSpineTransformBehavior;
  I, J, K, L: Integer;
  Bone: PspBone;
  OldTransformList: TCastleTransformList;
  TransformName: String;
begin
  if Self.FspSkeleton = nil then Exit;
  OldTransformList := TCastleTransformList.Create;
  try
    OldTransformList.OwnsObjects := False;
    for I := 0 to Self.Count - 1 do
    begin
      T := Self.Items[I];
      if T.FindBehavior(TCastleSpineTransformBehavior) <> nil then
        OldTransformList.Add(T);
    end;
    // Generate new transforms, skip if old transforms is found
    for I := 0 to Self.FspSkeleton^.bonesCount - 1 do
    begin
      Bone := Self.FspSkeleton^.bones[I];
      TransformName := ValidName(Self.FExposeTransformsPrefix + Bone^.data^.name);
      for J := 0 to Self.FExposeTransforms.Count - 1 do
      begin
        if Self.FExposeTransforms[J] = Bone^.data^.name then
        begin
          T := nil;
          for K := 0 to OldTransformList.Count - 1 do
            if OldTransformList[K].Name = TransformName then
            begin
              T := OldTransformList[K];
              OldTransformList.Delete(K);
              B := T.FindBehavior(TCastleSpineTransformBehavior) as TCastleSpineTransformBehavior;
              Break;
            end;
          if T = nil then
          begin
            T := TCastleTransform.Create(Self);
            T.Name := TransformName;
            Self.Add(T);
            B := TCastleSpineTransformBehavior.Create(T);
            B.Name := T.Name + '_Behavior';
            T.AddBehavior(B);
          end;
          B.Bone := Bone;
          for L := 0 to Length(Self.FspSkeletonDefault) - 1 do
            if Self.FspSkeletonDefault[I].data^.name = Bone^.data^.name then
            begin
              B.BoneDefault := @Self.FspSkeletonDefault[I];
              Break;
            end;
        end;
      end;
    end;
    // Remove remaining old transforms
    for I := 0 to OldTransformList.Count - 1 do
      OldTransformList[I].Free;
    InternalCastleDesignInvalidate := True;
  finally
    OldTransformList.Free;
  end;
  Self.FIsNeedRefreshBones := False;
end;

procedure TCastleSpine.SetAutoAnimation(const S: String);
begin
  Self.FAutoAnimation := S;
  if Self.FAutoAnimation <> '' then
    Self.PlayAnimation(Self.FAutoAnimation, Self.FAutoAnimationLoop)
  else
    Self.StopAnimation;
end;

procedure TCastleSpine.SetAutoAnimationLoop(const V: Boolean);
begin
  Self.FAutoAnimationLoop := V;
  if Self.FAutoAnimation <> '' then
    Self.PlayAnimation(Self.FAutoAnimation, Self.FAutoAnimationLoop);
end;

procedure TCastleSpine.SetColorForPersistent(const AValue: TVector4);
begin
  Self.FColor := AValue;
end;

procedure TCastleSpine.SetExposeTransforms(const Value: TStrings);
begin
  Self.FExposeTransforms.Assign(Value);
end;

procedure TCastleSpine.SetExposeTransformsPrefix(const S: String);
var
  T: TCastleTransform;
  B: TCastleSpineTransformBehavior;
  I: Integer;
  Bone: PspBone;
begin
  Self.FExposeTransformsPrefix := S;
  // Rename transforms
  for I := 0 to Self.Count - 1 do
  begin
    T := Self.Items[I];
    B := T.FindBehavior(TCastleSpineTransformBehavior) as TCastleSpineTransformBehavior;
    if B <> nil then
    begin
      T.Name := ValidName(Self.FExposeTransformsPrefix + B.Bone^.data^.name);
      B.Name := T.Name + '_Behavior';
      InternalCastleDesignInvalidate := True;
    end;
  end;
end;

function TCastleSpine.GetColorForPersistent: TVector4;
begin
  Result := Self.FColor;
end;

constructor TCastleSpine.Create(AOwner: TComponent);
begin
  inherited;
  Self.FColor := Vector4(1, 1, 1, 1);
  Self.FSmoothTexture := True;
  Self.FParameters := TPlayAnimationParameters.Create;
  Self.FAutoAnimationLoop := True;
  Self.FExposeTransforms := TStringList.Create;
  Self.FControlBoneList := TCastleSpineControlBoneList.Create;
  TStringList(Self.FExposeTransforms).OnChange := @Self.ExposeTransformsChange;
  Self.FColorPersistent := CreateColorPersistent(
    @Self.GetColorForPersistent,
    @Self.SetColorForPersistent,
    Self.FColor
  );
end;

destructor TCastleSpine.Destroy;
begin
  Self.Cleanup;
  Self.FParameters.Free;
  Self.FColorPersistent.Free;
  Self.FExposeTransforms.Free;
  Self.FControlBoneList.Free;
  inherited;
end;

{$ifdef CASTLE_DESIGN_MODE}
function TCastleSpine.PropertySections(
  const PropertyName: String): TPropertySections;
begin
  if (PropertyName = 'ExposeTransforms') then
    Result := [psBasic]
  else
    Result := inherited PropertySections(PropertyName);
end;
{$endif}

procedure TCastleSpine.LoadSpine(const AURL: String);
begin
  Self.FURL := AURL;
  Self.FIsNeedRefresh := True;
end;

procedure TCastleSpine.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
var
  F: Single;
  D: TCastleSpineControlBone;
begin
  inherited;
  CurrentSpineInstance := Self;
  Self.GLContextOpen;

  if not Self.Exists then
    Exit;

  if Self.FIsNeedRefresh then
    Self.InternalLoadSpine;
  if Self.FIsNeedRefreshAnimation then
    Self.InternalPlayAnimation;
  if Self.FIsNeedRefreshBones then
    Self.InternalExposeTransformsChange;

  RemoveMe := rtNone;
  // Update
  if Self.FIsGLContextInitialized and (Self.FspAnimationState <> nil) then
  begin
    if Self.TimePlaying then
      F := SecondsPassed * Self.TimePlayingSpeed
    else
      F := SecondsPassed;
    Inc(Self.FTicks);
    Self.FSecondsPassedAcc := Self.FSecondsPassedAcc + F;
    if Self.ProcessEvents then
    begin
      if (Self.FTicks > Self.AnimateSkipTicks) and ((Self.AnimateOnlyWhenVisible and Self.Visible) or (not Self.AnimateOnlyWhenVisible)) then
      begin
        if Self.FIsAnimationPlaying then
        begin
          spAnimationState_update(Self.FspAnimationState, Self.FSecondsPassedAcc);
          spAnimationState_apply(Self.FspAnimationState, Self.FspSkeleton);
        end;
        // Override bone values
        if Self.FControlBoneList.Count > 0 then
        begin
          for D in Self.FControlBoneList do
          begin
            D.Bone^.x := D.X;
            D.Bone^.y := D.Y;
            D.Bone^.rotation := D.Rotation;
          end;
        end;
        spSkeleton_updateWorldTransform(Self.FspSkeleton);
        spSkeletonBounds_update(Self.FspSkeletonBounds, Self.FspSkeleton, True);
        Self.FControlBoneList.Clear;
        Self.FTicks := 0;
        Self.FSecondsPassedAcc := 0;
      end;
    end;
  end;
  CurrentSpineInstance := nil;
end;

procedure TCastleSpine.LocalRender(const Params: TRenderParams);

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
    ClipAttachment: PspClippingAttachment;
    Slot: PspSlot;
    TotalVertexCount: Cardinal;
    PreviousImage: TDrawableImage = nil;
    Image: TDrawableImage;
    PreviousBlendMode: Integer = -1;
    AttachmentColor: TspColor;
    Color: TVector4;
    VertexCount,
    IndexCount: Cardinal;
    VertexPtr: PSingle;
    IndexPtr: PWord;
    UVPtr: PSingle;

    procedure Render; inline;
    begin
      if TotalVertexCount = 0 then
        Exit;
      // Render result
      if Image.SmoothScaling <> Self.FSmoothTexture then
        Image.SmoothScaling := Self.FSmoothTexture;

      glBindTexture(GL_TEXTURE_2D, Image.Texture);

      glBufferSubData(GL_ARRAY_BUFFER, 0, TotalVertexCount * SizeOf(TCastleSpineVertex), @SpineVertices[0]);

      glDrawArrays(GL_TRIANGLES, 0, TotalVertexCount);

      TotalVertexCount := 0;
      PreviousImage := Image;
      PreviousBlendMode := Integer(Slot^.data^.blendMode);
      if not Self.ExcludeFromStatistics then
      begin
        Inc(Params.Statistics.ShapesRendered);
        Inc(Params.Statistics.ShapesVisible);
      end;
    end;

  begin
    TotalVertexCount := 0;

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(0));
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(8));
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, SizeOf(TCastleSpineVertex), Pointer(16));

    for J := 0 to Skeleton^.slotsCount - 1 do
    begin
      Slot := Skeleton^.drawOrder[J];
      Attachment := Slot^.Attachment;

      if Attachment = nil then Continue;
      if (Slot^.color.a = 0) or (not Slot^.bone^.active) then
      begin
        spSkeletonClipping_clipEnd(Self.FspClipper, Slot);
        Continue;
      end;

      case Attachment^.type_ of
        SP_ATTACHMENT_REGION:
          begin
            RegionAttachment := PspRegionAttachment(Attachment);
            AttachmentColor := RegionAttachment^.color;
            if AttachmentColor.a = 0 then
            begin
              spSkeletonClipping_clipEnd(Self.FspClipper, Slot);
              Continue;
            end;
            Image := TDrawableImage(PspAtlasRegion(RegionAttachment^.rendererObject)^.page^.rendererObject);
            spRegionAttachment_computeWorldVertices(RegionAttachment, Slot, @WorldVerticesPositions[0], 0, 2);
            if PreviousImage = nil then
            begin
              PreviousImage := Image;
            end;
            VertexCount := 4;
            IndexCount := 6;
            VertexPtr := @WorldVerticesPositions[0];
            IndexPtr := @RegionIndices[0];
            UVPtr := RegionAttachment^.uvs;
          end;
        SP_ATTACHMENT_MESH:
          begin
            MeshAttachment := PspMeshAttachment(Attachment);
            AttachmentColor := RegionAttachment^.color;
            if (MeshAttachment^.super.worldVerticesLength > High(WorldVerticesPositions)) then continue;
            if AttachmentColor.a = 0 then
            begin
              spSkeletonClipping_clipEnd(Self.FspClipper, Slot);
              Continue;
            end;
            Image := TDrawableImage(PspAtlasRegion(MeshAttachment^.rendererObject)^.page^.rendererObject);
            spVertexAttachment_computeWorldVertices(@MeshAttachment^.super, Slot, 0, MeshAttachment^.Super.worldVerticesLength, @WorldVerticesPositions[0], 0, 2);
            if PreviousImage = nil then
            begin
              PreviousImage := Image;
            end;
            VertexCount := MeshAttachment^.super.worldVerticesLength shr 1;
            IndexCount := MeshAttachment^.trianglesCount;
            VertexPtr := @WorldVerticesPositions[0];
            IndexPtr := MeshAttachment^.triangles;
            UVPtr := MeshAttachment^.uvs;
          end;
        SP_ATTACHMENT_CLIPPING:
          begin
            ClipAttachment := PspClippingAttachment(Attachment);
            spSkeletonClipping_clipStart(Self.FspClipper, Slot, ClipAttachment);
            Continue;
          end;
        else
          Continue;
      end;

      // Flush the current pipeline if material change
      if (PreviousBlendMode <> Integer(Slot^.data^.blendMode)) or (PreviousImage <> Image) then
      begin
        // Blend mode
        if Integer(Slot^.data^.blendMode) <> PreviousBlendMode then
        begin
          if Self.FSpineData^.Atlas^.pages^.pma <> 0 then
          begin
            case Slot^.data^.blendMode of
              SP_BLEND_MODE_ADDITIVE:
                glBlendFunc(GL_ONE, GL_ONE);
              else
                glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
            end;
          end else
          begin
            case Slot^.data^.blendMode of
              SP_BLEND_MODE_ADDITIVE:
                glBlendFunc(GL_SRC_ALPHA, GL_ONE);
              else
                glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end;
          end;
        end;
        Render;
        PreviousBlendMode := Integer(Slot^.data^.blendMode);
        PreviousImage := Image;
      end;

      Color := Vector4(
        Skeleton^.color.r * Slot^.color.r * AttachmentColor.r,
        Skeleton^.color.g * Slot^.color.g * AttachmentColor.g,
        Skeleton^.color.b * Slot^.color.b * AttachmentColor.b,
        Skeleton^.color.a * Slot^.color.a * AttachmentColor.a
      );

      if spSkeletonClipping_isClipping(Self.FspClipper) then
      begin
        spSkeletonClipping_clipTriangles(Self.FspClipper, VertexPtr, VertexCount shl 1, IndexPtr, IndexCount, UVPtr, 2);
        VertexPtr := Self.FspClipper^.clippedVertices^.items;
        VertexCount := Self.FspClipper^.clippedVertices^.size shr 1;
        UVPtr := Self.FspClipper^.clippedUVs^.items;
        IndexPtr := Self.FspClipper^.clippedTriangles^.items;
        IndexCount := Self.FspClipper^.clippedTriangles^.size;
      end;

      // Build mesh
      // TODO: Separate indices / vertices to save bandwidth
      for I := 0 to IndexCount - 1 do
      begin
        Indx := IndexPtr[I] shl 1;
        AddVertex(VertexPtr[Indx], VertexPtr[Indx + 1],
            UVPtr[Indx], 1 - UVPtr[Indx + 1],
            Color, TotalVertexCount);
      end;

      spSkeletonClipping_clipEnd(Self.FspClipper, Slot);
    end;
    Render;
    spSkeletonClipping_clipEnd2(Self.FspClipper);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    if not Self.ExcludeFromStatistics then
    begin
      Inc(Params.Statistics.ScenesRendered);
    end;
  end;

var
  PreviousProgram: TGLSLProgram;
  Fog: TFogFunctionality;
  RenderCameraPosition: TVector3;
  RelativeBBox: TBox3D;
begin
  inherited;
  if Self.FspAnimationState = nil then
    Exit;
  if not Self.FIsGLContextInitialized then
    Exit;
  if (not Self.Visible) or (not Self.Exists) or Params.InShadow or (not Params.Transparent) or (Params.StencilTest > 0) then
    Exit;

  if not Self.ExcludeFromStatistics then
  begin
    Inc(Params.Statistics.ScenesVisible);
  end;
  if DistanceCulling > 0 then
  begin
    RenderCameraPosition := Params.InverseTransform^.MultPoint(Params.RenderingCamera.Position);
    if RenderCameraPosition.Length > DistanceCulling + LocalBoundingBox.Radius then
      Exit;
  end;
  if Self.FspSkeletonBounds^.minX < Self.FspSkeletonBounds^.maxX then
  begin
    RelativeBBox := Box3D(
      Vector3(Self.FspSkeletonBounds^.minX, Self.FspSkeletonBounds^.minY, -0.0001),
      Vector3(Self.FspSkeletonBounds^.maxX, Self.FspSkeletonBounds^.maxY, 0.0001)
    );
    if not Params.Frustum^.Box3DCollisionPossibleSimple(RelativeBBox) then
      Exit;
  end;

  PreviousProgram := RenderContext.CurrentProgram;
  RenderProgram.Enable;

  RenderProgram.Uniform('mvMatrix').SetValue(Params.RenderingCamera.Matrix * Params.Transform^);
  RenderProgram.Uniform('pMatrix').SetValue(RenderContext.ProjectionMatrix);
  RenderProgram.Uniform('color').SetValue(Self.FColor);
  if Self.FEnableFog and (Params.GlobalFog <> nil) then
  begin
    Fog := (Params.GlobalFog as TFogNode).Functionality(TFogFunctionality) as TFogFunctionality;
    RenderProgram.Uniform('fogEnable').SetValue(1);
    RenderProgram.Uniform('fogEnd').SetValue(Fog.VisibilityRange);
    RenderProgram.Uniform('fogColor').SetValue(Fog.Color);
  end else
    RenderProgram.Uniform('fogEnable').SetValue(0);

  glEnable(GL_DEPTH_TEST);
  glEnable(GL_BLEND);
  glDepthMask(GL_FALSE);
  glActiveTexture(GL_TEXTURE0);

  RenderSkeleton(Self.FspSkeleton);

  glDisable(GL_BLEND);
  glDisable(GL_DEPTH_TEST);
  glDepthMask(GL_TRUE);

  PreviousProgram.Enable;
end;

function TCastleSpine.LocalBoundingBox: TBox3D;
begin
  if (Self.FspSkeletonBounds <> nil) and Exists then
  begin
    Result := Box3D(
      Vector3(Self.FspSkeletonBounds^.minX, Self.FspSkeletonBounds^.minY, -0.0001),
      Vector3(Self.FspSkeletonBounds^.maxX, Self.FspSkeletonBounds^.maxY, 0.0001)
    );
  end else
    Result := TBox3D.Empty;
  Result.Include(inherited LocalBoundingBox);
end;

function TCastleSpine.PlayAnimation(const Parameters: TPlayAnimationParameters): boolean;
begin
  Self.FParameters.Name := Parameters.Name;
  Self.FParameters.Loop := Parameters.Loop;
  Self.FParameters.Forward := Parameters.Forward;
  Self.FParameters.TransitionDuration := Parameters.TransitionDuration;
  Self.FTrack := 0;
  Self.FIsAnimationPlaying := True;
  Self.FIsNeedRefreshAnimation := True;
  Result := True;
end;

function TCastleSpine.PlayAnimation(const AnimationName: string; const Loop: boolean; const Forward: boolean; const Track: Integer = 0): boolean;
begin
  Self.FParameters.Name := AnimationName;
  Self.FParameters.Loop := Loop;
  Self.FParameters.Forward := Forward;
  Self.FParameters.TransitionDuration := Self.DefaultAnimationTransition;
  Self.FTrack := Track;
  Self.FIsAnimationPlaying := True;
  Self.FIsNeedRefreshAnimation := True;
  Result := True;
end;

procedure TCastleSpine.StopAnimation(const Track: Integer = -1);
begin
  Self.FIsAnimationPlaying := False;
  if Track < 0 then
    spAnimationState_clearTracks(Self.FspAnimationState)
  else
    spAnimationState_clearTrack(Self.FspAnimationState, Track);
end;

procedure TCastleSpine.InternalPlayAnimation;

  function IsAnimationExists: Boolean;
  var
    I: Integer;
  begin
    for I := 0 to Self.FSpineData^.SkeletonData^.animationsCount - 1 do
      if Self.FSpineData^.SkeletonData^.animations[I]^.Name = Self.FParameters.Name then
        Exit(True);
    Exit(False);
  end;

var
  TrackEntry: PspTrackEntry;

begin
  if Self.FspAnimationState = nil then Exit;
  CurrentSpineInstance := Self;
  if IsAnimationExists then
  begin
    if (Self.FPreviousAnimation <> '') and (Self.FPreviousAnimation <> Self.FParameters.Name) then
    begin
      spAnimationStateData_setMixByName(Self.FSpineData^.AnimationStateData, PChar(Self.FPreviousAnimation), PChar(Self.FParameters.Name), Self.FParameters.TransitionDuration);
    end;
    TrackEntry := spAnimationState_setAnimationByName(Self.FspAnimationState, Self.FTrack, PChar(Self.FParameters.Name), Self.FParameters.Loop);
    TrackEntry^.reverse := Integer(not Self.FParameters.Forward);
    Self.FPreviousAnimation := Self.FParameters.Name;
  end;
  Self.FIsNeedRefreshAnimation := False;
  CurrentSpineInstance := nil;
end;

initialization
  RegisterSerializableComponent(TCastleSpine, 'Spine');
  RegisterSerializableComponent(TCastleSpineTransformBehavior, 'Spine Transform Behavior');
  {$ifdef CASTLE_DESIGN_MODE}
  RegisterPropertyEditor(TypeInfo(TStrings), TCastleSpine, 'ExposeTransforms',
    TExposeTransformsPropertyEditor);
  {$endif}
  SpineDataCache := TCastleSpineDataCache.Create;

finalization
  SpineDataCache.Free;

end.
