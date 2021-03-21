unit Execute.GLB;
{
  GLB Viewer for Delphi Sydney (c)2011 Execute SARL <contact@execute.fr>
}
interface

uses
  Winapi.Windows,
  System.JSON,
  System.Generics.Collections,
  System.SysUtils,
  System.Classes;

const
  GLB_MAGIC = $46546C67; // 'glTF'
  GLB_JSON  = $4E4f534a; // 'JSON'
  GLB_BIN   = $004e4942; // 'BIN'#0

  glTF_UNSIGNED_BYTE = 5121;
  glTF_UNSIGNED_SHORT = 5123;
  glTF_FLOAT = 5126;

  NULL_OFFSET = Cardinal(-1);

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

  TGLBModel = class;

  TGLBParser = record
    Model: TGLBModel;
    JSON: TJSONObject;
    scene: Integer;
    scenes: TJSONArray;
    nodes : TJSONArray;
    materials: TJSONArray;
    meshes: TJSONArray;
    textures: TJSONArray;
    images: TJSONArray;
    accessors: TJSONArray;
    bufferViews: TJSONArray;
    procedure Load(AModel: TGLBModel; AScript: TBytes);
    procedure LoadScene(AScene: Cardinal);
    procedure LoadNodes(ANodes: TArray<Cardinal>);
    procedure LoadNode(ANode: Cardinal);
    procedure LoadMesh(AMesh: Cardinal);
    procedure LoadMaterial(AMaterial: Cardinal);
    procedure LoadImage(AImage: Cardinal);
  end;

  TGLBNode = record
    name: string;
    mesh: Cardinal;
    rotation: TArray<Single>;
    scale: TArray<single>;
    translation: TArray<Single>;
    children: TArray<Cardinal>;
  end;

  TPrimitive = record
  private
    procedure Load(var Parser: TGLBParser; const APrimitive: TJSONValue);
  public
    vertexCount: Cardinal;
    position: Cardinal;
    normal: Cardinal;

    texcoord: Cardinal;

    indiceCount: Cardinal;
    indices: Cardinal;

    material: Cardinal;
  end;

  TGLBMesh = record
    name: string;
    primitives: TArray<TPrimitive>;
  end;

  TGLBMaterial = record
    Name: string;
    BaseColorFactor: TArray<Single>;
    Image: Cardinal;
  end;

  TGLBImage = record
    Name: string;
    MimeType: string;
    Offset: Cardinal;
    Size: Cardinal;
  end;

  TGLBModel = class
  protected
    FBuffer   : TBytes;
    FName     : string;
    FScene    : TArray<Cardinal>;
    FNodes    : TArray<TGLBNode>;
    FMeshes   : TArray<TGLBMesh>;
    FMaterials: TArray<TGLBMaterial>;
    FImages   : TArray<TGLBImage>;
  public
    procedure LoadFromStream(Stream: TStream);
  end;

implementation

{ TGLBParser }

procedure TGLBParser.Load(AModel: TGLBModel; AScript: TBytes);
begin
  Model := AModel;
  JSON := TJSONObject.Create;
  try
    if JSON.Parse(AScript, 0) < 0 then
      raise Exception.Create('Can''t Parse JSON');

  // SanityCheck
    var buffers := JSON.GetValue<TJSONArray>('buffers');
    Assert(buffers.Count = 1);
    Assert(buffers[0].GetValue<Integer>('byteLength') = Length(Model.FBuffer));

  // Main structure
    scenes := JSON.GetValue<TJSONArray>('scenes');
    nodes := JSON.GetValue<TJSONArray>('nodes');
    materials := JSON.GetValue<TJSONArray>('materials');
    meshes := JSON.GetValue<TJSONArray>('meshes');
    textures := JSON.GetValue<TJSONArray>('textures');
    images := JSON.GetValue<TJSONArray>('images');
    accessors := JSON.GetValue<TJSONArray>('accessors');
    bufferViews := JSON.GetValue<TJSONArray>('bufferViews');

    SetLength(Model.FNodes, nodes.Count);
    SetLength(Model.FMeshes, meshes.Count);
    SetLength(Model.FMaterials, materials.Count);
    SetLength(Model.FImages, images.Count);

    LoadScene(JSON.GetValue<Integer>('scene'));
  finally
    JSON.Free;
  end;
end;

procedure TGLBParser.LoadScene(AScene: Cardinal);
var
  scene: TJSONValue;
begin
  if AScene >= scenes.Count then
    raise Exception.Create('scene out of bounds');
  scene := scenes[AScene];
  Model.FName := scene.GetValue<string>('name');
  Model.FScene := scene.GetValue<TArray<Cardinal>>('nodes');
  LoadNodes(Model.FScene);
end;

procedure TGLBParser.LoadNodes(ANodes: TArray<Cardinal>);
var
  Index: Integer;
begin
  for Index := 0 to Length(ANodes) - 1 do
  begin
    LoadNode(ANodes[Index]);
  end;
end;

procedure TGLBParser.LoadNode(ANode: Cardinal);
var
  node: TJSONValue;
  mesh: Cardinal;
begin
  if ANode >= nodes.Count then
    raise Exception.Create('node out of bounds');

  if Model.FNodes[ANode].Name <> '' then
    Exit;

  node := nodes[ANode];

  Model.FNodes[ANode].Name := node.GetValue<string>('name');

  node.TryGetValue<TArray<Single>>('rotation', Model.FNodes[ANode].rotation);
  node.TryGetValue<TArray<Single>>('scale', Model.FNodes[ANode].scale);
  node.TryGetValue<TArray<Single>>('translation', Model.FNodes[ANode].translation);

  if node.TryGetValue<Cardinal>('mesh', mesh) then
  begin
    LoadMesh(mesh);
  end else begin
    mesh := NULL_OFFSET;
  end;
  Model.FNodes[ANode].mesh := mesh;

  if node.TryGetValue<TArray<Cardinal>>('children', Model.FNodes[ANode].children) then
  begin
    LoadNodes(Model.FNodes[ANode].children);
  end;
end;

procedure TGLBParser.LoadMesh(AMesh: Cardinal);
var
  mesh: TJSONValue;
  primitives: TJSONArray;
  Index: Integer;
begin
  if AMesh >= meshes.Count then
    raise Exception.Create('mesh out of bounds');

  if Model.FMeshes[AMesh].Name <> '' then
    Exit;

  mesh := meshes[AMesh];

  Model.FMeshes[AMesh].Name := mesh.GetValue<string>('name');

  primitives := mesh.GetValue<TJSONArray>('primitives');

  SetLength(Model.FMeshes[AMesh].primitives, primitives.Count);

  for Index := 0 to primitives.Count - 1 do
  begin
    Model.FMeshes[AMesh].primitives[Index].Load(Self, primitives[Index]);
  end;
end;

procedure TGLBParser.LoadMaterial(AMaterial: Cardinal);
var
  pbrMetallicRoughness: TJSONValue;
  baseColorTexture: TJSONValue;
  index: Cardinal;
begin
  if AMaterial >= materials.Count then
    raise Exception.Create('material out of bounds');

  if Model.FMaterials[AMaterial].Name <> '' then
    Exit;

  pbrMetallicRoughness := materials[AMaterial].GetValue<TJSONValue>('pbrMetallicRoughness');

  pbrMetallicRoughness.TryGetValue<TArray<Single>>('baseColorFactor', Model.FMaterials[AMaterial].BaseColorFactor);

  if pbrMetallicRoughness.TryGetValue<TJSONValue>('baseColorTexture', baseColorTexture) then
  begin
    Assert(baseColorTexture.GetValue<Integer>('texCoord') = 0);
    index := baseColorTexture.GetValue<Cardinal>('index');
    if index >= textures.Count then
      raise Exception.Create('texture out of bounds');
    Model.FMaterials[AMaterial].Image := textures[index].GetValue<Cardinal>('source');
    LoadImage(Model.FMaterials[AMaterial].Image);
  end else begin
    Model.FMaterials[AMaterial].Image := NULL_OFFSET;
  end;
end;

procedure TGLBParser.LoadImage(AImage: Cardinal);
var
  bufferView: Cardinal;
begin
  if AImage > images.Count then
    raise Exception.Create('image out of bounds');

  if Model.FImages[AImage].Name <> '' then
    Exit;

  Model.FImages[AImage].Name := images[AImage].GetValue<string>('name');
  Model.FImages[AImage].MimeType := images[AImage].GetValue<string>('mimeType');

  bufferView := images[AImage].GetValue<Cardinal>('bufferView');
  Model.FImages[AImage].Offset := bufferViews[bufferView].GetValue<Cardinal>('byteOffset');
  Model.FImages[AImage].Size := bufferViews[bufferView].GetValue<Cardinal>('byteLength');
end;

{ TPrimitive }

procedure TPrimitive.Load(var Parser: TGLBParser; const APrimitive: TJSONValue);
var
  attributes: TJSONValue;
  POSITION,
  NORMAL,
  TEXCOORD_0,
  indices: record
    accessor: TJSONValue;
    bufferView: TJSONValue;
  end;
  Texture: Cardinal;
begin
  attributes := APrimitive.GetValue<TJSONValue>('attributes');

  POSITION.accessor := Parser.accessors[attributes.GetValue<Integer>('POSITION')];
  POSITION.bufferView := Parser.bufferViews[POSITION.accessor.GetValue<Integer>('bufferView')];

  NORMAL.accessor := Parser.accessors[attributes.GetValue<Integer>('NORMAL')];
  NORMAL.bufferView := Parser.bufferViews[NORMAL.accessor.GetValue<Integer>('bufferView')];

  vertexCount := POSITION.accessor.GetValue<Integer>('count');

// SanityCheck
  Assert(POSITION.accessor.GetValue<string>('type') = 'VEC3');
  Assert(POSITION.accessor.GetValue<Cardinal>('componentType') = glTF_FLOAT);

  Assert(NORMAL.accessor.GetValue<string>('type') = 'VEC3');
  Assert(NORMAL.accessor.GetValue<Cardinal>('componentType') = glTF_FLOAT);
  Assert(NORMAL.accessor.GetValue<Cardinal>('count') = vertexCount);

  Assert(POSITION.bufferView.GetValue<Cardinal>('buffer') = 0);
  Assert(POSITION.bufferView.GetValue<Cardinal>('byteLength') = vertexCount * 3 * SizeOf(Single));
  Assert(NORMAL.bufferView.GetValue<Cardinal>('buffer') = 0);
  Assert(NORMAL.bufferView.GetValue<Cardinal>('byteLength') = vertexCount * 3 * SizeOf(Single));

  Self.position := POSITION.bufferView.GetValue<Cardinal>('byteOffset');
  Self.normal := NORMAL.bufferView.GetValue<Cardinal>('byteOffset');

  if attributes.TryGetValue<Cardinal>('TEXCOORD_0', Texture) then
  begin
    TEXCOORD_0.accessor := Parser.accessors[attributes.GetValue<Integer>('TEXCOORD_0')];
    TEXCOORD_0.bufferView := Parser.bufferViews[TEXCOORD_0.accessor.GetValue<Integer>('bufferView')];

    Assert(TEXCOORD_0.accessor.GetValue<string>('type') = 'VEC2');
    Assert(TEXCOORD_0.accessor.GetValue<Integer>('componentType') = glTF_FLOAT);
    Assert(TEXCOORD_0.accessor.GetValue<Integer>('count') = vertexCount);

    Assert(TEXCOORD_0.bufferView.GetValue<Integer>('buffer') = 0);
    Assert(TEXCOORD_0.bufferView.GetValue<Integer>('byteLength') = vertexCount * 2 * SizeOf(Single));

    texcoord := TEXCOORD_0.bufferView.GetValue<Cardinal>('byteOffset');
  end else begin
    texcoord := NULL_OFFSET;
  end;

  //todo: TEXCOORD_1, TEXCOORD_2

  indices.accessor := Parser.accessors[APrimitive.GetValue<Integer>('indices')];
  indices.bufferView := Parser.bufferViews[indices.accessor.GetValue<Integer>('bufferView')];

  indiceCount := indices.accessor.GetValue<Integer>('count');

  Assert(indices.accessor.GetValue<string>('type') = 'SCALAR');
  Assert(indices.accessor.GetValue<Integer>('componentType') = glTF_UNSIGNED_SHORT);
  Assert(indices.bufferView.GetValue<Integer>('buffer') = 0);
  Assert(indices.bufferView.GetValue<Cardinal>('byteLength') = indiceCount * SizeOf(Word));

  Self.indices := indices.bufferView.GetValue<Integer>('byteOffset');

  material := APrimitive.GetValue<Integer>('material');
  Parser.LoadMaterial(material);
end;

{ TGLBModel }

procedure TGLBModel.LoadFromStream(Stream: TStream);
var
  Header : TGLBHeader;
  Chunk  : TGLBChunk;
  Script : TBytes;
  Pad    : Integer;
  Parser : TGLBParser;
begin
  Stream.Read(Header, SizeOf(Header));
  if Header.magic <> GLB_MAGIC then
    raise Exception.Create('Not a GLB file');

  Stream.Read(Chunk, SizeOf(Chunk));
  if Chunk.chunkType <> GLB_JSON then
    raise Exception.Create('Expected GLB JSON Chunk not found');
  SetLength(Script, Chunk.chunkLength);
  Stream.Read(Script[0], Chunk.chunkLength);

  Pad := SizeOf(Header) + SizeOf(Chunk) + Chunk.chunkLength;
  Pad := Pad mod 4;
  if Pad <> 0 then
  begin
    Stream.Seek(4 - Pad, TSeekOrigin.soCurrent);
  end;

  Stream.Read(Chunk, SizeOf(Chunk));
  if Chunk.chunkType <> GLB_BIN then
    raise Exception.Create('Expected GLB BIN Chunk not found');
  SetLength(FBuffer, Chunk.chunkLength);
  Stream.Read(FBuffer[0], Chunk.chunkLength);

  Assert(Integer(Header.length) = SizeOf(Header) + 2 * SizeOf(Chunk) + Length(Script) + Length(FBuffer), 'Wrong data size');

  Parser.Load(Self, Script);
end;

end.
