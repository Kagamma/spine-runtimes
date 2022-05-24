unit Spine;

{$macro on}
{$mode delphi}
{$define SPINECALL:=cdecl}
{$if defined(windows)}
  {$define SPINELIB:='libspine-c.dll'}
{$elseif defined(darwin)}
  {$define SPINELIB:='libspine-c.dylib'}
{$else}
  {$define SPINELIB:='libspine-c.so'}
{$endif}

interface

uses
  Classes,
  ctypes, dynlibs;

type
  TspBlendMode = (
	  SP_BLEND_MODE_NORMAL, SP_BLEND_MODE_ADDITIVE, SP_BLEND_MODE_MULTIPLY, SP_BLEND_MODE_SCREEN
  );
  TspAttachmentType = (
    SP_ATTACHMENT_REGION,
    SP_ATTACHMENT_BOUNDING_BOX,
    SP_ATTACHMENT_MESH,
    SP_ATTACHMENT_LINKED_MESH,
    SP_ATTACHMENT_PATH,
    SP_ATTACHMENT_POINT,
    SP_ATTACHMENT_CLIPPING
  );
  TspAtlasFormat = (
    SP_ATLAS_UNKNOWN_FORMAT,
    SP_ATLAS_ALPHA,
    SP_ATLAS_INTENSITY,
    SP_ATLAS_LUMINANCE_ALPHA,
    SP_ATLAS_RGB565,
    SP_ATLAS_RGBA4444,
    SP_ATLAS_RGB888,
    SP_ATLAS_RGBA8888
  );
  TspAtlasFilter = (
    SP_ATLAS_UNKNOWN_FILTER,
    SP_ATLAS_NEAREST,
    SP_ATLAS_LINEAR,
    SP_ATLAS_MIPMAP,
    SP_ATLAS_MIPMAP_NEAREST_NEAREST,
    SP_ATLAS_MIPMAP_LINEAR_NEAREST,
    SP_ATLAS_MIPMAP_NEAREST_LINEAR,
    SP_ATLAS_MIPMAP_LINEAR_LINEAR
  );
  TspAtlasWrap = (
    SP_ATLAS_MIRROREDREPEAT,
    SP_ATLAS_CLAMPTOEDGE,
    SP_ATLAS_REPEAT
  );

  TspColor = record
    r, g, b, a: cfloat;
  end;
  PspColor = ^TspColor;

  PspKeyValueArray = Pointer;

  PspSkeletonJson = Pointer;
  PspSkeletonData = Pointer;
  PspAnimationStateData = Pointer;
  PSpAnimationState = Pointer;
  PspBoneData = Pointer;

  PspAttachmentLoader = Pointer;

  TspAttachment = record
    name: Pchar;
    type_: TspAttachmentType;
    vtable: Pointer;
    refCount: cint;
    attachmentLoader: PspAttachmentLoader;
  end;
  PspAttachment = ^TspAttachment;

  TspRegionAttachment = record
    super: TspAttachment;
    path: PChar;
    x, y, scaleX, scaleY, rotation, width, height: cfloat;
    color: TspColor;
    rendererObject: Pointer;
    regionOffsetX, regionOffsetY: cint;
    regionWidth, regionHeight: cint;
    regionOriginalWidth, regionOriginalHeight: cint;
    offset: array[0..7] of cfloat;
    uvs: array[0..7] of cfloat;
  end;
  PspRegionAttachment = ^TspRegionAttachment;

  PspAtlas = ^TspAtlas;

  PspAtlasPage = ^TspAtlasPage;
  TspAtlasPage = record
    atlas: PspAtlas;
    name: PChar;
    format: TspAtlasFormat;
    minFilter, magFilter: TspAtlasFilter;
    uWrap, vWrap: TspAtlasWrap;
    rendererObject: Pointer;
    width, height: cint;
    pma: cint;
    next: PspAtlasPage;
  end;

  PspAtlasRegion = ^TspAtlasRegion;
  TspAtlasRegion = record
    name: PChar;
    x, y, width, height: cint;
    u, v, u2, v2: cfloat;
    offsetX, offsetY: cint;
    originalWidth, originalHeight: cint;
    index_: cint;
    degrees: cint;
    splits: ^cint;
    pads: ^cint;
    keyValues: PspKeyValueArray;
    page: PspAtlasPage;
    next: PspAtlasRegion;
  end;

  TspAtlas = record
    pages: PspAtlasPage;
    regions: PspAtlasRegion;
    rendererObject: Pointer;
  end;

  PspBone = Pointer;
  PPspBone = ^PspBone;

  PspIkConstraint = Pointer;
  PPspIkConstraint = ^PspIkConstraint;

  PspTransformConstraint = Pointer;
  PPspTransformConstraint = ^PspTransformConstraint;

  PspPathConstraint = Pointer;
  PPspPathConstraint = ^PspPathConstraint;

  PspSkin = Pointer;
  PPspSkin = ^PspSkin;

  TspSlotData = record
    index_: cint;
    name: PChar;
    boneData: PspBoneData;
    attachmentName: PChar;
    color: TspColor;
    darkColor: PspColor;
    blendMode: TspBlendMode;
  end;
  PspSlotData = ^TspSlotData;

  TspSlot = record
    data: PspSlotData;
    bone: PspBone;
    color: TspColor;
    darkColor: PspColor;
    attachment: PspAttachment;
    attachmentState: cint;
  end;
  PspSlot = ^TspSlot;
  PPspSlot = ^PspSlot;

  PSpSkeleton = ^TSpSkeleton;
  TspSkeleton = record
    data: PspSkeletonData;

    bonesCount: cint;
    bones: PPspBone;
    root: PspBone;

    slotsCount: cint;
    slots: PPspSlot;
    drawOrder: PPspSlot;

    ikConstraintsCount: cint;
    ikConstraints: PPspIkConstraint;
    transformConstraintsCount: cint;
    transformConstraints: PPspTransformConstraint;
    pathConstraintsCount: cint;
    pathConstraints: PPspPathConstraint;
    skin: PspSkin;
    color: TspColor;
    time: cfloat;
    scaleX, scaleY: cfloat;
    x, y: cfloat;
  end;

  PspVertexAttachment = ^TspVertexAttachment;
  TspVertexAttachment = record
    super: TspAttachment;
    bonesCount: cint;
    bones: ^cint;
    verticesCount: cint;
    vertices: ^cfloat;
    worldVerticesLength: cint;
    deformAttachment: PspVertexAttachment;
    id: cint;
  end;

  PspMeshAttachment = ^TspMeshAttachment;
  TspMeshAttachment = record
    super: TspVertexAttachment;
    rendererObject: Pointer;
    regionOffsetX, regionOffsetY: cint;
    regionWidth, regionHeight: cint;
    regionOriginalWidth, regionOriginalHeight: cint;
    regionU, regionV, regionU2, regionV2: cfloat;
    regionDegrees: cint;
    path: PChar;
    regionUVs: ^cfloat;
    uvs: ^cfloat;
    trianglesCount: cint;
    triangles: ^cushort;
    color: TspColor;
    hullLength: cint;
    parentMesh: PspMeshAttachment;
    edgesCount: cint;
    edges: ^cint;
    width, height: cfloat;
  end;

var
  // ----- Loader -----
  { FileName: PWideChar; Data: Pointer; var Size: cuint32 }
  Spine_Loader_RegisterLoadRoutine: procedure(Func: Pointer); SPINECALL;
  Spine_Loader_RegisterLoadTextureRoutine: procedure(Func: Pointer); SPINECALL;
  Spine_Loader_RegisterFreeTextureRoutine: procedure(Func: Pointer); SPINECALL;

  // Memory management
  _spMalloc: function(Size: Cardinal; F: PChar; L: Integer): Pointer; SPINECALL;

  // Atlas
  spAtlas_create: function(Data: Pointer; Len: cint; Dir: PChar; rendererObject: Pointer): PspAtlas; SPINECALL;
  spAtlas_dispose: procedure(Atlas: PspAtlas); SPINECALL;

  // Skeleton
  spSkeletonJson_create: function(Atlas: PspAtlas): PspSkeleton; SPINECALL;
  spSkeletonJson_readSkeletonData: function(SkeletonJson: PspSkeletonJson; Data: PChar): PspSkeletonData; SPINECALL;
  spSkeletonJson_dispose: procedure(SkeletonJson: PspSkeletonJson); SPINECALL;
  spSkeleton_create: function(SkeletonData: PspSkeletonData): PspSkeleton; SPINECALL;
  spSkeleton_dispose: procedure(Skeleton: PspSkeleton); SPINECALL;
  spSkeletonData_dispose: procedure(SkeletonData: PspSkeletonData); SPINECALL;

  // Animation
  spAnimationStateData_create: function(SkeletonData: PspSkeletonData): PspAnimationStateData; SPINECALL;
  spAnimationStateData_dispose: procedure(AnimationStateData: PspAnimationStateData); SPINECALL;
  spAnimationStateData_setMixByName: procedure(AnimationStateData: PspAnimationStateData; FromName, ToName: PChar; Duration: cfloat); SPINECALL;
  spAnimationState_setAnimationByName: procedure(AnimationState: PSpAnimationState; TrackIndex: cint; AnimationName: PChar; Loop: cint); SPINECALL;
  spAnimationState_update: procedure(AnimationState: PSpAnimationState; Delta: cfloat); SPINECALL;
  spAnimationState_apply: procedure(AnimationState: PSpAnimationState; Skeleton: PspSkeleton); SPINECALL;
  spAnimationState_updateWorldTransform: procedure(Skeleton: PspSkeleton); SPINECALL;

  // Attachment
  spRegionAttachment_computeWorldVertices: procedure(This: PspRegionAttachment; Bone: PSpBone; Vertices: pcfloat; Offset, Stride: cint); SPINECALL;
  spVertexAttachment_computeWorldVertices: procedure(This: PspVertexAttachment; Slot: PSpSlot; Start, Count: cint; Vertices: pcfloat; Offset, Stride: cint); SPINECALL;

function Spine_Load: Boolean;

implementation

var
  Lib: TLibHandle = dynlibs.NilHandle;

function Spine_Load: Boolean;
begin;
  // library already loaded, subsequent calls to Spine_Load do nothing
  if Lib <> dynlibs.NilHandle then Exit(True);

  Lib := LoadLibrary(SPINELIB);
  if Lib = dynlibs.NilHandle then Exit(False);

  Spine_Loader_RegisterLoadRoutine := GetProcedureAddress(Lib, 'Spine_Loader_RegisterLoadRoutine');
  Spine_Loader_RegisterLoadTextureRoutine := GetProcedureAddress(Lib, 'Spine_Loader_RegisterLoadTextureRoutine');
  Spine_Loader_RegisterFreeTextureRoutine := GetProcedureAddress(Lib, 'Spine_Loader_RegisterFreeTextureRoutine');

  // Memory management
  _spMalloc := GetProcedureAddress(Lib, '_spMalloc');

  // Atlas
  spAtlas_create := GetProcedureAddress(Lib, 'spAtlas_create');
  spAtlas_dispose := GetProcedureAddress(Lib, 'spAtlas_dispose');

  // Skeleton
  spSkeletonJson_create := GetProcedureAddress(Lib, 'spSkeletonJson_create');
  spSkeletonJson_readSkeletonData := GetProcedureAddress(Lib, 'spSkeletonJson_readSkeletonData');
  spSkeletonJson_dispose := GetProcedureAddress(Lib, 'spSkeletonJson_dispose');
  spSkeleton_create := GetProcedureAddress(Lib, 'spSkeleton_create');
  spSkeleton_dispose := GetProcedureAddress(Lib, 'spSkeleton_dispose');
  spSkeletonData_dispose := GetProcedureAddress(Lib, 'spSkeletonData_dispose');

  // Animation
  spAnimationStateData_create := GetProcedureAddress(Lib, 'spAnimationStateData_create');
  spAnimationStateData_dispose := GetProcedureAddress(Lib, 'spAnimationStateData_dispose');
  spAnimationStateData_setMixByName := GetProcedureAddress(Lib, 'spAnimationStateData_setMixByName');
  spAnimationState_setAnimationByName := GetProcedureAddress(Lib, 'spAnimationState_setAnimationByName');
  spAnimationState_update := GetProcedureAddress(Lib, 'spAnimationState_update');
  spAnimationState_apply := GetProcedureAddress(Lib, 'spAnimationState_apply');
  spAnimationState_updateWorldTransform := GetProcedureAddress(Lib, 'spAnimationState_updateWorldTransform');

  // Attachment
  spRegionAttachment_computeWorldVertices := GetProcedureAddress(Lib, 'spRegionAttachment_computeWorldVertices');
  spVertexAttachment_computeWorldVertices := GetProcedureAddress(Lib, 'spVertexAttachment_computeWorldVertices');

  Exit(True);
end;

end.