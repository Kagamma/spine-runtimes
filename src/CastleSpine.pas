unit CastleSpine;

interface

uses
  Classes, SysUtils, Spine,
  CastleDownload, CastleLog;

implementation

{ Provide loader function for Spine }
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

end.