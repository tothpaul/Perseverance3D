unit Execute.GLBBuilder;

interface

uses
  System.Classes,
  System.SysUtils;

const
  GLB_MAGIC = $46546C67; // 'glTF'
  GLB_JSON  = $4E4f534a; // 'JSON'
  GLB_BIN   = $004e4942; // 'BIN'#0

  glTF_UNSIGNED_BYTE = 5121;
  glTF_UNSIGNED_SHORT = 5123;
  glTF_FLOAT = 5126;

type
  TGLBHeader = record
    magic: Cardinal;
    version: Cardinal;
    length: Cardinal;
  end;

  TGLBChunk = record
    chunkLength: Cardinal;
    chunkType: Cardinal;
  //chunkData: TBytes;
  // 4-byte padding
  end;

  TPoint3f = record
    x, y, z: Single;
  end;

  TFace3i = record
    a, b, c: Word;
  end;

  TGLBBuilder = class;

  TGLBBuilderPrimitive = class
  private
    FPoints: TArray<TPoint3f>;
    FNormals: TArray<TPoint3f>;
    FFaces : TArray<TFace3i>;
    FJSON: UTF8String;
    function toJSON(Builder: TGLBBuilder): UTF8String;
  public
    function AddPoint(x, y, z: Single): Integer;
    function AddNormal(x, y, z: Single): Integer;
    function AddFace(a, b, c: Word): Integer;
  end;

  TGLBBuilderMesh = class
  private
    FSibling: TGLBBuilderMesh;
    FIndex: Integer;
    function toJSON(Builder: TGLBBuilder): UTF8String;
  public
    Material: Integer;
    Primitive: TGLBBuilderPrimitive;
  end;

  TGLBBuilderNode = class
  private
    FSibling: TGLBBuilderNode;
    FIndex: Integer;
    FNodes: TArray<TGLBBuilderNode>;
    FTranslation: TArray<Single>;
    FRotation: TArray<Single>;
    FMaterial: Integer;
    function toJSON: UTF8String;
  public
    Mesh: TGLBBuilderMesh;
    function AddNode(Node: TGLBBuilderNode): Integer;
    procedure Translate(x, y, z: Single);
    procedure Rotate(x, y, z, w: Single);
  end;

  TGLBBuilder = class
  private
    JSON: UTF8String;
    Buffers: TBytes;
    FScene: TArray<TGLBBuilderNode>;
    FNodes: TGLBBuilderNode;
    FMeshes: TGLBBuilderMesh;
    FBufferViews: UTF8String;
    FBufferView : Integer;
    FAccessors: UTF8String;
    FColors: TArray<Cardinal>;
    function AddBuffer(Data: Pointer; Len, Component, Count: Integer; const dataType: UTF8String): Integer;
    function AddPoints(const Points: TArray<TPoint3f>): Integer;
    function AddFaces(const Faces: TArray<TFace3i>): Integer;
    function MaterialColor(Index: Integer): UTF8String;
  public
    function AddNode(Scene: Boolean): TGLBBuilderNode;
    function AddMesh(Primitive: TGLBBuilderPrimitive): TGLBBuilderMesh;
    function AddMaterialColor(Color: Cardinal): Integer;
    procedure SaveToFile(const AFileName: string);
  end;
implementation

{ TGLBBuilderPrimitive }

function TGLBBuilderPrimitive.AddPoint(x, y, z: Single): Integer;
begin
  Result := Length(FPoints);
  SetLength(FPoints, Result + 1);
  FPoints[Result].x := x;
  FPoints[Result].y := y;
  FPoints[Result].z := z;
end;

function TGLBBuilderPrimitive.AddNormal(x, y, z: Single): Integer;
begin
  Result := Length(FNormals);
  SetLength(FNormals, Result + 1);
  FNormals[Result].x := x;
  FNormals[Result].y := y;
  FNormals[Result].z := z;
end;

function TGLBBuilderPrimitive.AddFace(a, b, c: Word): Integer;
begin
  Result := Length(FFaces);
  SetLength(FFaces, Result + 1);
  FFaces[Result].a := a;
  FFaces[Result].b := b;
  FFaces[Result].c := c;
end;

function TGLBBuilderPrimitive.toJSON(Builder: TGLBBuilder): UTF8String;
begin
  if FJSON = '' then
  begin
    FJSON := '"attributes":{'
           + '"POSITION":' + IntToStr(Builder.AddPoints(FPoints)) + ','
           + '"NORMAL":' + IntToStr(Builder.AddPoints(FNormals))
           + '},'
           + '"indices":' + IntToStr(Builder.AddFaces(FFaces));
  end;
  Result := FJSON;
end;

{ TGLBBuilderMesh }

function TGLBBuilderMesh.toJSON(Builder: TGLBBuilder): UTF8String;
begin
  Result := '{"name":"Mesh' + IntToStr(FIndex) + '",'
          + '"primitives":[{'
          + Primitive.toJSON(Builder)
          + ',"material":' + IntToStr(Material)
          + '}]}';
end;

{ TGLBBuilderNode }

function TGLBBuilderNode.AddNode(Node: TGLBBuilderNode): Integer;
begin
  Result := Length(FNodes);
  SetLength(FNodes, Result + 1);
  FNodes[Result] := Node;
end;

procedure TGLBBuilderNode.Rotate(x, y, z, w: Single);
begin
  FRotation := [x, y, z, w];
end;

function TGLBBuilderNode.toJSON: UTF8String;
var
  Index: Integer;
begin
  Result := '{"name":"Node' + IntToStr(FIndex) + '"';
  if Mesh <> nil then
    Result := Result + ',"mesh":' + IntToStr(Mesh.FIndex);
  if Length(FTranslation) = 3 then
    Result := Result + ',"translation":[' + Format('%.2f,%.2f,%.2f', [FTranslation[0], FTranslation[1], FTranslation[2]], TFormatSettings.Invariant) + ']';
  if Length(FRotation) = 4 then
    Result := Result + ',"rotation":[' + Format('%.2f,%.2f,%.2f,%.2f', [FRotation[0], FRotation[1], FRotation[2], FRotation[3]], TFormatSettings.Invariant) + ']';
  if FNodes <> nil then
  begin
    Result := Result + ',"children":[' + IntToStr(FNodes[0].FIndex);
    for Index := 1 to Length(FNodes) - 1 do
    begin
      Result := Result + ',' + IntToStr(FNodes[Index].FIndex);
    end;
    Result := Result + ']';
  end;
  Result := Result + '}';
end;

procedure TGLBBuilderNode.Translate(x, y, z: Single);
begin
  FTranslation := [x, y, z];
end;

{ TGLBBuilder }

function TGLBBuilder.AddNode(Scene: Boolean): TGLBBuilderNode;
var
  Len: Integer;
begin
  Result := TGLBBuilderNode.Create;
  if FNodes <> nil then
  begin
    Result.FIndex := FNodes.FIndex + 1;
    Result.FSibling := FNodes.FSibling;
    FNodes.FSibling := Result;
  end else begin
    Result.FSibling := Result;
  end;
  FNodes := Result;
  if Scene then
  begin
    Len := Length(FScene);
    SetLength(Fscene, Len + 1);
    FScene[Len] := Result;
  end;
end;

function TGLBBuilder.AddBuffer(Data: Pointer; Len, Component, Count: Integer;
  const dataType: UTF8String): Integer;
begin
  Result := FBufferView;
  if FAccessors <> '' then
    FAccessors := FAccessors + ',';
  FAccessors := FAccessors +
    '{"bufferView":' + IntToStr(FBufferView) + ','
  + '"componentType":' + IntToStr(Component) + ','
  + '"count":' + IntToStr(Count) + ','
  + '"type":"' + dataType + '"}';
  if FBufferView > 0 then
    FBufferViews := FBufferViews + ',';
  FBufferViews := FBufferViews +
    '{"buffer":0,"byteLength":' + IntToStr(Len)+',"byteOffset":' + IntToStr(Length(Buffers)) + '}';
  Inc(FBufferView);
  Count := Length(Buffers);
  SetLength(Buffers, Count + Len);
  Move(Data^, Buffers[Count], Len);
end;

function TGLBBuilder.AddFaces(const Faces: TArray<TFace3i>): Integer;
begin
  Result := AddBuffer(Faces, Length(Faces) * SizeOF(TFace3i), glTF_UNSIGNED_SHORT, 3 * Length(Faces), 'SCALAR');
end;

function TGLBBuilder.AddPoints(const Points: TArray<TPoint3f>): Integer;
begin
  Result := AddBuffer(Points, Length(Points) * SizeOF(TPoint3f), glTF_FLOAT, Length(Points), 'VEC3');
end;

function TGLBBuilder.MaterialColor(Index: Integer): UTF8String;
var
  c: Cardinal;
  f: array[0..3] of Single;
  i: Integer;
begin
  c := FColors[Index];
  for i := 0 to 3 do
  begin
    f[i] := (c and $FF)/$FF;
    c := c shr 8;
  end;
  Result :='{"name":"Mat' + IntToStr(Index) + '","pbrMetallicRoughness":{"baseColorFactor":['
   + Format('%.2f,%.2f,%.2f,%.2f', [f[0], f[1], f[2], f[3]], TFormatSettings.Invariant)
   + ']}}';
end;

function TGLBBuilder.AddMaterialColor(Color: Cardinal): Integer;
var
  Index: Integer;
begin
  Result := Length(FColors);
  for Index := 0 to Result - 1 do
  begin
    if FColors[Index] = Color then
      Exit(Index);
  end;
  SetLength(FColors, Result + 1);
  FColors[Result] := Color;
end;

function TGLBBuilder.AddMesh(Primitive: TGLBBuilderPrimitive): TGLBBuilderMesh;
begin
  Result := TGLBBuilderMesh.Create;
  Result.Primitive := Primitive;
  if FMeshes <> nil then
  begin
    Result.FIndex := FMeshes.FIndex + 1;
    Result.FSibling := FMeshes.FSibling;
    FMeshes.FSibling := Result;
  end else begin
    Result.FSibling := Result;
  end;
  FMeshes := Result;
end;

procedure TGLBBuilder.SaveToFile(const AFileName: string);
var
  Index: Integer;
  Node: TGLBBuilderNode;
  Mesh: TGLBBuilderMesh;
  Stream: TFileStream;
  header: TGLBHeader;
  chunk : TGLBChunk;
  pad   : Cardinal;
  zero  : Int64;
begin
  if FColors = nil then
    AddMaterialColor($FFFF0000);

  JSON := '{"asset":{"generator":"Execute.GLBBuilder v1.0","version":"2.0"},';
  JSON := JSON
    + '"scene":0,'
    + '"scenes":['+
    '  {"name":"Scene",'
    +  '"nodes":[';
  JSON := JSON + IntToStr(FScene[0].FIndex);
  for Index := 1 to Length(FScene) - 1 do
  begin
    JSON := JSON + ',' + IntToStr(FScene[Index].FIndex);
  end;

  JSON := JSON + ']}'
    + '],'
    + '"nodes":[';
  Node := FNodes.FSibling;
  JSON := JSON + Node.toJSON;
  while Node <> FNodes do
  begin
    Node := Node.FSibling;
    JSON := JSON + ',' + Node.toJSON;
  end;

  JSON := JSON
    + '],'
    + '"meshes":[';
  Mesh := FMeshes.FSibling;
  JSON := JSON + Mesh.toJSON(Self);
  while Mesh <> FMeshes do
  begin
    Mesh := Mesh.FSibling;
    JSON := JSON + ',' + Mesh.toJSON(Self);
  end;

  JSON := JSON
    + '],'
    + '"materials":['
    + MaterialColor(0);
  for Index := 1 to Length(FColors) - 1 do
    JSON := JSON + ',' + MaterialColor(Index);
  JSON := JSON
    + '],'
    + '"textures":[],'
    + '"images":[],'
    + '"accessors":[' + FAccessors + '],'
    + '"bufferViews":[' + FBufferViews + '],'
    + '"buffers":[{"byteLength":' + IntToStr(Length(Buffers)) + '}]}';

  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    Header.magic := GLB_MAGIC;
    Header.version := 2;
    pad := (SizeOf(Header) + SizeOf(Chunk) + Length(JSON)) mod 4;
    if pad > 0 then
      pad := 4 - pad;
    Header.length := SizeOf(Header) + 2 * SizeOf(Chunk) + Length(JSON) + pad + Length(Buffers);
    Stream.Write(Header, SizeOf(Header));
    Chunk.chunkLength := Length(JSON);
    Chunk.chunkType := GLB_JSON;
    Stream.Write(Chunk, SizeOf(Chunk));
    Stream.Write(JSON[1], Length(JSON));
    zero := 0;
    Stream.Write(zero, pad);
    Chunk.chunkLength := Length(Buffers);
    Chunk.chunkType := GLB_BIN;
    Stream.Write(Chunk, SizeOf(Chunk));
    Stream.Write(Buffers[0], Length(Buffers));
  finally
    Stream.Free;
  end;
end;

end.
