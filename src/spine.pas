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

  PspSkeletonData = Pointer;
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

  PspAtlas = Pointer;

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
  PspSlotData = Pointer;

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

  TspSkeleton = record
    data: PspSkeletonData;
    bonesCount: cint;
    bones: PPspBone;
    root: PspBone;
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
  _spMalloc: function(Size: Cardinal; F: PChar; L: Integer): Pointer; SPINECALL;

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
  _spMalloc := GetProcedureAddress(Lib, '_spMalloc');

  Exit(True);
end;

end.