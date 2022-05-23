unit CastleSpine;

interface

uses
  Spine;

implementation

{ Provide loader function for Spine }
procedure LoaderLoad(FileName: PWideChar; var MS: TMemoryStream; var Data: Pointer; var Size: LongWord); cdecl;
var
  S: String;
  MS: TMemoryStream;
begin
  try
    S := FileName;
    // In case it load a material, force it to load .efkmat instead of .efkmatd
    if LowerCase(ExtractFileExt(FileName)) = '.efkmatd' then
      Delete(S, Length(S), 1);
    MS := Download(S, [soForceMemoryStream]) as TMemoryStream;
    // Data is managed by spine-c, so we call malloc
    Data := _spMalloc(Size, nil, 0);
    Size := MS.Size;
    // Copy data from MS to Data
    Move(MS.Memory^, Data^, Size);
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

end.