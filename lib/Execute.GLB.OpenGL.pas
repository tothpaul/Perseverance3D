unit Execute.GLB.OpenGL;
{
  GLB Viewer for Delphi Sydney (c)2011 Execute SARL <contact@execute.fr>
}
interface
{$IFDEF DEBUG}
//{$DEFINE LOG}
{$ENDIF}
uses
  Winapi.Windows,
  Winapi.OpenGL,
  Winapi.OpenGLext,
  System.Math,
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  Vcl.Graphics,
  Vcl.Imaging.jpeg,
  Vcl.Imaging.pngimage,
  Execute.GLB;

type
  TGLBOpenGLModel = class(TGLBModel)
  private
    FGLBuffer: Integer;
    FTextures: TArray<GLUint>;
    procedure RenderNodes(ANodes: TArray<Cardinal>);
    procedure RenderNode(ANode: Cardinal);
    procedure RenderMesh(AMesh: Cardinal);
    procedure RenderPrimitives(const APrimitives: TArray<TPrimitive>);
    procedure SelectMaterial(AMaterial: Cardinal);
    procedure LoadTexture(AImage: Cardinal);
  public
    procedure Clear;
    procedure Render;
  end;

implementation

procedure glQuaternion(x, y, z, w: Single);
var
 tw,scale:single;
begin
  tw := 2 * ArcCos(w);
  if Abs(tw) < 0.001 then
    Exit;
  scale := (x * x + y * y + z * z);
  if Abs(scale) < 0.001 then
    Exit;
  scale := 1 / scale;
  glRotatef(tw * 180 / PI, x * scale, y * scale, z * scale);
end;

{ TGLBOpenGLModel }

procedure TGLBOpenGLModel.Clear;
var
  Index: Integer;
begin
  if FGLBuffer <> 0 then
  begin
    glDeleteBuffers(1, @FGLBuffer);
    FGLBuffer := 0;
  end;
  for Index := 0 to Length(FTextures) - 1 do
  begin
    if FTextures[Index] <> 0 then
      glDeleteTextures(1, @FTextures[Index]);
  end;
  FTextures := nil;
end;

procedure TGLBOpenGLModel.Render;
begin
  if FGLBuffer = 0 then
  begin
    if FScene = nil then
      Exit;
    glGenBuffers(1, @FGLBuffer);

    glBindBuffer(GL_ARRAY_BUFFER, FGLBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, FGLBuffer);
    // todo: do not load the Images into the VBO !
    glBufferData(GL_ARRAY_BUFFER, Length(FBuffer), FBuffer, GL_STATIC_DRAW);
//    glBufferData(GL_ELEMENT_ARRAY_BUFFER, Length(FBuffer), FBuffer, GL_STATIC_DRAW);

    SetLength(FTextures, Length(FImages));
  end;

  glEnableClientState(GL_VERTEX_ARRAY);
  glEnableClientState(GL_NORMAL_ARRAY);
  glEnableClientState(GL_TEXTURE_COORD_ARRAY);
  glEnableClientState(GL_INDEX_ARRAY);
  RenderNodes(FScene);
  glDisableClientState(GL_VERTEX_ARRAY);
  glDisableClientState(GL_NORMAL_ARRAY);
  glDisableClientState(GL_TEXTURE_COORD_ARRAY);
  glDisableClientState(GL_INDEX_ARRAY);
end;

procedure TGLBOpenGLModel.RenderNodes(ANodes: TArray<Cardinal>);
var
  Index: Integer;
begin
  for Index := 0 to Length(ANodes) - 1 do
  begin
    RenderNode(ANodes[Index]);
  end;
end;

procedure TGLBOpenGLModel.RenderNode(ANode: Cardinal);
begin
{$IFDEF LOG} AllocConsole; WriteLn('Node#', ANode);{$ENDIF}
  glPushMatrix;
  with FNodes[ANode] do
  begin
    if Length(translation) = 3 then
    begin
      glTranslatef(translation[0], translation[1], translation[2]);
    end;
    if Length(rotation) = 4 then
    begin
      glQuaternion(rotation[0], rotation[1], rotation[2], rotation[3]);
    end;
    if Length(scale) = 3 then
    begin
      glScalef(scale[0], scale[1], scale[2]);
    end;
    RenderMesh(mesh);
    RenderNodes(children);
  end;
  glPopMatrix;
end;

procedure TGLBOpenGLModel.RenderMesh(AMesh: Cardinal);
begin
{$IFDEF LOG}WriteLn(' Mesh ', AMesh);{$ENDIF}
  if AMesh = NULL_OFFSET then
    Exit;
  RenderPrimitives(FMeshes[AMesh].primitives);
end;

procedure TGLBOpenGLModel.RenderPrimitives(const APrimitives: TArray<TPrimitive>);
var
  Index: Integer;
begin
  for Index := 0 to Length(APrimitives) - 1 do
  begin
  {$IFDEF LOG}WriteLn('  Primitive ', Index);{$ENDIF}
    with APrimitives[Index] do
    begin
      SelectMaterial(Material);
      glVertexPointer(3, GL_FLOAT, 3 * SizeOf(Single), Pointer(position));
      glNormalPointer(GL_FLOAT, 3 * SizeOf(Single), Pointer(normal));
      glTexCoordPointer(2, GL_FLOAT, 2 * SizeOf(Single), Pointer(texcoord));
      glDrawElements(GL_TRIANGLES, indiceCount, GL_UNSIGNED_SHORT, Pointer(indices));
    end;
  end;
end;

procedure TGLBOpenGLModel.SelectMaterial(AMaterial: Cardinal);
begin
{$IFDEF LOG}WriteLn('   Material ', AMaterial);{$ENDIF}
// todo: material colors
  if Length(FMaterials[AMaterial].BaseColorFactor) = 4 then
  begin
    glColor4fv(PGLfloat(FMaterials[AMaterial].BaseColorFactor));
//  end else begin
//    glColor3f(1, 0, 0);
  end;
  if FMaterials[AMaterial].Image = NULL_OFFSET then
  begin
    glDisable(GL_TEXTURE_2D);
//    glColor3f(1, 0, 0);
  end else begin
    glEnable(GL_TEXTURE_2D);
    glColor3f(1, 1, 1);
    LoadTexture(FMaterials[AMaterial].Image);
  end;
end;

procedure REVERT(P: Pointer; W, H, D: Integer);
var
  L1, L2: PByte;
  x, y, o: Integer;
  t: Byte;
begin
  L1 := P;
  L2 := P;
  Inc(L2, W * H * D);
  for y := 0 to (H div 2) - 1 do
  begin
    Dec(L2, W * D);
    o := 0;
    for x := 0 to W - 1 do
    begin
      t := L1[o + 0];
      L1[o + 0] := L2[o + 2];
      L2[o + 2] := t;

      t := L1[o + 2];
      L1[o + 2] := L2[o + 0];
      L2[o + 0] := t;

      t := L1[o + 1];
      L1[o + 1] := L2[o + 1];
      L2[o + 1] := t;

      if D = 4 then
      begin
        t := L1[o + 3];
        L1[o + 3] := L2[o + 3];
        L2[o + 3] := t;
      end;

      Inc(o, D);

    end;
    Inc(L1, W * D);
  end;
end;

procedure glTexImage2D(Target,level:integer; components,width,height:integer; border,format,DataType:integer; pixels:pointer); stdcall external opengl32;

procedure TGLBOpenGLModel.LoadTexture(AImage: Cardinal);
var
  SRC: TBytesStream;
  BMP: TBitmap;
  JPG: TJPEGImage;
  PNG: TPNGImage;
  TEX: PCardinal;
begin
{$IFDEF LOG}WriteLn('    Texture ', AImage);{$ENDIF}
  if FTextures[AImage] > 0 then
  begin
    glBindTexture(GL_TEXTURE_2D, FTextures[AImage]);
  end else begin
    glGenTextures(1, @FTextures[AImage]);
    glBindTexture(GL_TEXTURE_2D, FTextures[AImage]);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);

    SRC := TBytesStream.Create(FBuffer);
  {$IFDEF DEBUG}
//    TFile.WriteAllBytes(IntToStr(AImage) + '.' + FImages[AImage].Name + '.' + Copy(FImages[AImage].MimeType, 7), Copy(FBuffer, FImages[AImage].Offset, FImages[AImage].Size));
  {$ENDIF}
    BMP := TBitmap.Create;
    try
      SRC.Position := FImages[AImage].Offset;
      if FImages[AImage].MimeType = 'image/jpeg' then
      begin
        JPG := TJPEGImage.Create;
        try
          JPG.LoadFromStream(SRC);
          BMP.Assign(JPG);
        finally
          JPG.Free;
        end;
      end else
      if FImages[AImage].MimeType = 'image/png' then
      begin
        PNG := TPNGImage.Create;
        try
          PNG.LoadFromStream(SRC);
          BMP.Assign(PNG);
        finally
          PNG.Free;
        end;
      end else
        raise Exception.Create('Unsupported image format ' + FImages[AImage].MimeType);
      TEX := BMP.ScanLine[BMP.Height - 1];
      if BMP.PixelFormat = pf24Bit then
      begin
        REVERT(TEX, BMP.Width, BMP.Height, 3);
        glTexImage2D(GL_TEXTURE_2D, 0, 3, BMP.Width, BMP.Height, 0, GL_RGB, GL_UNSIGNED_BYTE, TEX);
      end else
      if BMP.PixelFormat = pf32bit then
      begin
        REVERT(TEX, BMP.Width, BMP.Height, 4);
        glTexImage2D(GL_TEXTURE_2D, 0, 4, BMP.Width, BMP.Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, TEX);
      end else
        raise Exception.Create('Unsupported pixel format');
  {$IFDEF DEBUG}
//    BMP.SaveToFile(IntToStr(AImage) + '.' + FImages[AImage].Name + '.bmp');
  {$ENDIF}
    finally
      BMP.Free;
      SRC.Free;
    end;
  end;
end;

end.
