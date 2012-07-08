unit UntMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Buttons,
  Vcl.ToolWin, Vcl.ImgList, Vcl.ExtCtrls, clMultiDC, clMultiUploader,
  clHttpRequest, Vcl.ExtDlgs, Vcl.Menus, clConnection, clDCUtils, clDc, Clipbrd,
  jpeg, ShlwApi, WinInet;

type
  TfrmMain = class(TForm)
    stMain: TStatusBar;
    tlbMain: TToolBar;
    ilNormal: TImageList;
    btnAdd: TToolButton;
    btnPaste: TToolButton;
    btnDelete: TToolButton;
    btnSp1: TToolButton;
    btnClear: TToolButton;
    btnSp2: TToolButton;
    btnSettings: TToolButton;
    btnAbout: TToolButton;
    btnQuit: TToolButton;
    lvQueue: TListView;
    muUploader: TclMultiUploader;
    dlgOpen: TOpenPictureDialog;
    pmToolbar: TPopupMenu;
    mniLockToolbar: TMenuItem;
    mniShowCaption: TMenuItem;
    Tray: TTrayIcon;
    pmTray: TPopupMenu;
    mniSpeed: TMenuItem;
    mniSp1: TMenuItem;
    mniShowWindow: TMenuItem;
    mniQuit: TMenuItem;
    pmList: TPopupMenu;
    mniCopy: TMenuItem;
    conUploader: TclInternetConnection;
    procedure FormCreate(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure mniShowCaptionClick(Sender: TObject);
    procedure mniLockToolbarClick(Sender: TObject);
    procedure btnQuitClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure mniShowWindowClick(Sender: TObject);
    procedure mniQuitClick(Sender: TObject);
    procedure pmListPopup(Sender: TObject);
    procedure lvQueueDblClick(Sender: TObject);
    procedure muUploaderDataItemProceed(Sender: TObject; Item: TclInternetItem;
      ResourceInfo: TclResourceInfo; AStateItem: TclResourceStateItem;
      CurrentData: PAnsiChar; CurrentDataSize: Integer);
    procedure mniCopyClick(Sender: TObject);
    procedure btnDeleteClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure muUploaderStatusChanged(Sender: TObject; Item: TclInternetItem;
      Status: TclProcessStatus);
    procedure muUploaderError(Sender: TObject; Item: TclInternetItem;
      const Error: string; ErrorCode: Integer);
    procedure muUploaderIsBusyChanged(Sender: TObject);
    procedure muUploaderProcessCompleted(Sender: TObject;
      Item: TclInternetItem);
    procedure btnPasteClick(Sender: TObject);
    procedure mniSpeedClick(Sender: TObject);
    procedure TrayDblClick(Sender: TObject);
    procedure btnAboutClick(Sender: TObject);
  private
    { Private declarations }
    ForceClose: Boolean;
    function QuickAcion(): String;
    procedure CompleteRequest(HttpRequest: TclHttpRequest;
      const fileName: string; isFromURL: Boolean);
    procedure AddUploadItem(const fileName: string;
      isFromClipboard: Boolean = false; isFromURL: Boolean = false);
    procedure DoRealClose();
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;
  TempDir: string;

resourcestring
  defaultUA =
    'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0)';
  defaultHost = 'http://www.imagecraft.tk/api.php';

implementation

{$R *.dfm}

{ TForm1 }
function SaveClipboardTextDataToFile(sFileTo: string): Boolean;
var
  ps1, ps2: PChar;
  dwLen: DWord;
  tf: TextFile;
  hData: THandle;
begin
  Result := false;
  with Clipboard do
  begin
    try
      Open;
      if (HasFormat(CF_TEXT)) then
      begin
        hData := GetClipboardData(CF_TEXT);
        ps1 := GlobalLock(hData);
        dwLen := GlobalSize(hData);
        ps2 := StrAlloc(1 + dwLen);
        StrLCopy(ps2, ps1, dwLen);
        GlobalUnlock(hData);
        AssignFile(tf, sFileTo);
        ReWrite(tf);
        Write(tf, ps2);
        CloseFile(tf);
        StrDispose(ps2);
        Result := True;
      end;
    finally
      Close;
    end;
  end;
end;

procedure TfrmMain.AddUploadItem(const fileName: string;
  isFromClipboard: Boolean = false; isFromURL: Boolean = false);
var
  uploadItem: TclUploadItem;
  listItem: TListItem;
begin
  uploadItem := muUploader.UploadList.add;
  uploadItem.RequestMethod := 'POST';
  uploadItem.UseHttpRequest := True;
  if (not Assigned(uploadItem.HttpRequest)) then
    uploadItem.HttpRequest := TclHttpRequest.Create(nil);
  CompleteRequest(uploadItem.HttpRequest, fileName, isFromURL);
  listItem := lvQueue.Items.add;
  with listItem do
  begin
    Caption := fileName;
    if (isFromClipboard) then
      Caption := '剪贴板';
    SubItems.Append('未知');
    SubItems.Append(FormatDateTime('hh:mm:ss', Now()));
    SubItems.Append('排队');
    if (not isFromURL) then
      SubItems.Append(fileName)
    else
      SubItems.Append('');
  end;

  uploadItem.Data := listItem;
  listItem.Data := uploadItem;
  uploadItem.URL := defaultHost;
  muUploader.Start(uploadItem);
end;

procedure TfrmMain.btnAboutClick(Sender: TObject);
begin
  MessageBox(Handle, PCHAR('这个工具只是闲着蛋疼时一时兴起所作的' + #13#10 + #13#10+ '使用API:' + #13#10+ defaultHost + #13#10#13#10 + '使用说明：' + #13#10 +
    '①“粘贴图像”功能支持图像和指向的图片网址' + #13#10 + '②图片大小勿超过8MB' + #13#10 +
    '③双击托盘图标执行“粘贴图像“操作' + #13#10 +'④双击列表中项目可以复制目标URL' +#13#10#13#10 + '如果有什么想问的，可以给我写E-Mail' + #13#10 +
    'indeed@indeedblog.net'), '关于', MB_OK + MB_ICONINFORMATION);

end;

procedure TfrmMain.btnAddClick(Sender: TObject);
var
  i: LongInt;
begin
  if (dlgOpen.Execute(Handle)) then
  begin
    for i := 0 to dlgOpen.Files.Count - 1 do
      AddUploadItem(dlgOpen.Files.Strings[i]);
  end;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  if MessageBox(Handle, '这将停止所有任务并将之删除，您确定吗？', '清空队列',
    MB_OKCANCEL + MB_ICONWARNING) = IDOK then
  begin
    muUploader.Stop();
    muUploader.UploadList.Clear;
    lvQueue.Clear;
  end;

end;

procedure TfrmMain.btnDeleteClick(Sender: TObject);
var
  uploadItem: TclUploadItem;
  listItem: TListItem;
  i: LongInt;
begin
  if (lvQueue.Selected = nil) then
    exit;
  listItem := lvQueue.Selected;
  uploadItem := listItem.Data;
  uploadItem.Stop;
  for i := 0 to muUploader.UploadList.Count - 1 do
    if (muUploader.UploadList.Items[i].Data = listItem) then
    begin
      muUploader.UploadList.Delete(i);
      break;
    end;
  listItem.Delete;
end;

procedure TfrmMain.btnPasteClick(Sender: TObject);
begin
  QuickAcion();
end;

function CheckUrl(URL: string): Boolean;
var
  hSession, hfile, hRequest: HINTERNET;
  dwindex, dwcodelen: DWord;
  dwcode: array [1 .. 20] of Char;
  res: PChar;
begin
  Result := false;
  if Pos('http://', LowerCase(URL)) = 0 then
    URL := 'http://' + URL;
  { Open an internet session }
  hSession := InternetOpen('InetURL:/1.0', INTERNET_OPEN_TYPE_PRECONFIG,
    nil, nil, 0);
  if Assigned(hSession) then
  begin
    hfile := InternetOpenUrl(hSession, PChar(URL), nil, 0,
      INTERNET_FLAG_RELOAD, 0);
    dwindex := 0;
    dwcodelen := 10;
    HttpQueryInfo(hfile, HTTP_QUERY_STATUS_CODE, @dwcode, dwcodelen, dwindex);
    res := PChar(@dwcode);
    Result := (res = '200') or (res = '302');
    if Assigned(hfile) then
      InternetCloseHandle(hfile);
    InternetCloseHandle(hSession);
  end;
end;

function GetAbsolutePathEx(BasePath, RelativePath: string): string;
var
  Dest: array [0 .. MAX_PATH] of Char;
begin
  FillChar(Dest, MAX_PATH + 1, 0);
  PathCombine(Dest, PChar(BasePath), PChar(RelativePath));
  Result := string(Dest);
end;

procedure TfrmMain.btnQuitClick(Sender: TObject);
begin
  DoRealClose();
end;

procedure TfrmMain.CompleteRequest(HttpRequest: TclHttpRequest;
  const fileName: string; isFromURL: Boolean);
var
  fileSubmitItem: TclSubmitFileRequestItem;
begin
  HttpRequest.ClearItems;
  HttpRequest.Header.UserAgent := defaultUA;
  HttpRequest.Header.Accept :=
    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8';
  HttpRequest.Header.AcceptCharSet := 'UTF-8,*;q=0.5';
  HttpRequest.Header.ContentType := 'multipart/form-data';
  HttpRequest.AddFormField('apikey', 'public');
  if not isFromURL then
  begin
    fileSubmitItem := HttpRequest.AddSubmitFile('image', fileName);
    fileSubmitItem.FieldName := 'image';
    fileSubmitItem.fileName := fileName; // Strange but I have to do so
  end
  else
  begin
    HttpRequest.AddFormField('remote', 'remote');
    HttpRequest.AddFormField('url', fileName);
  end;

end;

procedure TfrmMain.DoRealClose;
begin
  ForceClose := True;
  if (muUploader.IsBusy) then
    ForceClose := (MessageBox(Handle, '有任务正在进行，您确定要放弃所有任务并退出吗？', '退出',
      MB_YESNO + MB_ICONQUESTION) = IDYES);
  Close();
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  muUploader.Stop;
  Tray.Visible := false;
  Application.Terminate;
  ExitProcess(0);
end;

procedure TfrmMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ForceClose;
  if (not CanClose) then
    Hide;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  s:array[0..255] of Char;
begin
  GetTempPath(255, s);
  TempDir:=s;
  muUploader.InternetAgent := defaultUA;
  ForceClose := false;
end;

procedure TfrmMain.lvQueueDblClick(Sender: TObject);
begin
  if (lvQueue.Selected = nil) then
    exit;
  mniCopyClick(mniCopy);
end;

procedure TfrmMain.mniCopyClick(Sender: TObject);
begin
  if (lvQueue.Selected.SubItems[0] <> '未知') then
    Clipboard.SetTextBuf(PChar(lvQueue.Selected.SubItems[0]))
  else
    MessageBox(Handle, '没有可以复制的链接', '警告', MB_OK + MB_ICONWARNING);

end;

procedure TfrmMain.mniLockToolbarClick(Sender: TObject);
begin
  tlbMain.Customizable := not(Sender as TMenuItem).Checked;
end;

procedure TfrmMain.mniQuitClick(Sender: TObject);
begin
  DoRealClose;
end;

procedure TfrmMain.mniShowCaptionClick(Sender: TObject);
begin
  tlbMain.ShowCaptions := (Sender as TMenuItem).Checked;
end;

procedure TfrmMain.mniShowWindowClick(Sender: TObject);
begin
  Visible := not Visible;
end;

procedure TfrmMain.mniSpeedClick(Sender: TObject);
var
  s:string;
begin
  s:=QuickAcion;
  if (s<>'') then
  begin
    Tray.BalloonTitle := 'Image Quick Rehost';
    Tray.BalloonHint := s;
    tray.BalloonTimeout:= 2;
    tray.BalloonFlags:=bfInfo;
    Tray.ShowBalloonHint;
  end;
end;

procedure TfrmMain.muUploaderDataItemProceed(Sender: TObject;
  Item: TclInternetItem; ResourceInfo: TclResourceInfo;
  AStateItem: TclResourceStateItem; CurrentData: PAnsiChar;
  CurrentDataSize: Integer);
begin
  stMain.Panels[2].Text := '网络:' +
    inttostr(Round(AStateItem.ResourceState.Speed / 1024)) + 'KB/s';
  TListItem(Item.Data).SubItems[2] :=
    inttostr(Round(AStateItem.ResourceState.BytesProceed /
    AStateItem.ResourceState.ResourceSize)) + '%';
  stMain.Refresh;
end;

procedure TfrmMain.muUploaderError(Sender: TObject; Item: TclInternetItem;
  const Error: string; ErrorCode: Integer);
begin
  TListItem(Item.Data).SubItems[2] := '出错:' + inttostr(ErrorCode) + ' ' + Error;
end;

procedure TfrmMain.muUploaderIsBusyChanged(Sender: TObject);
begin
  if (muUploader.IsBusy) then
    stMain.Panels[0].Text := '忙碌'
  else
    stMain.Panels[0].Text := '就绪'
end;

procedure TfrmMain.muUploaderProcessCompleted(Sender: TObject;
  Item: TclInternetItem);
var
  listItem: TListItem;
  res: string;
begin
  listItem := (Item as TclUploadItem).Data;
  if (listItem.Caption <> listItem.SubItems.Strings[3]) then
    DeleteFile(listItem.SubItems.Strings[3]);
  if (Item.Errors.Text <> '') then
  begin
    res := (Item as TclUploadItem).HttpResponse.Text;
    listItem.SubItems.Strings[2] := '失败:' + Item.Errors.Errors[0] + ' ' + res;
  end
  else
  begin
    listItem := (Item as TclUploadItem).Data;
    listItem.SubItems.Strings[0] := (Item as TclUploadItem).HttpResponse.Text;
    listItem.SubItems.Strings[2] := '已完成';
  end;
  stMain.Panels[2].Text := '网络:空闲';
end;

procedure TfrmMain.muUploaderStatusChanged(Sender: TObject; Item: TclInternetItem;
  Status: TclProcessStatus);
var
  listItem: TListItem;
begin
  listItem := (Item as TclUploadItem).Data;
  if (Status = psErrors) then
  begin
    listItem.SubItems.Strings[2] := '出错';
  end
  else if (Status = psFailed) then
  begin
    listItem.SubItems.Strings[2] := '失败:' + (Item as TclUploadItem)
      .HttpResponse.Text;
  end
  else if (Status = psProcess) then
  begin
    listItem.SubItems.Strings[2] := '等待';
  end;

end;

procedure TfrmMain.pmListPopup(Sender: TObject);
begin
  pmList.Items[0].Enabled := lvQueue.Selected <> nil;
end;

function TfrmMain.QuickAcion: String;
var
  i: LongInt;
  pic: TPicture;
  jpeg: TJPEGImage;
  fileName: string;
  URL: string;
begin
  jpeg := nil;
  pic := nil;
  Result := '';
  try
    if Clipboard.HasFormat(CF_PICTURE) then
    begin
      pic := TPicture.Create;
      for i := 0 to Clipboard.FormatCount - 1 do
        if pic.SupportsClipboardFormat(Clipboard.Formats[i]) then
        begin
          jpeg := TJPEGImage.Create;
          pic.LoadFromClipboardFormat(Clipboard.Formats[i],
            Clipboard.GetAsHandle(Clipboard.Formats[i]), 0);
          jpeg.Assign(pic.Bitmap);
          fileName := GetAbsolutePathEx(TempDir,
            FormatDateTime('yyyymmddhhmmss', Now()) + inttostr(Random(10000))
            + '.jpg');
          jpeg.SaveToFile(fileName);
          AddUploadItem(fileName, True);
          Clipboard.Clear;
          Result := '剪贴板图形(转换为JPEG)';
          break;
        end;
    end;
    if Clipboard.HasFormat(CF_TEXT) then
    begin
      URL := trim(Clipboard.AsText);
      if CheckUrl(URL) then
      begin
        Clipboard.Clear;
        AddUploadItem(URL, false, True);
        Result:=URL;
      end
    end;

  finally
    if jpeg <> nil then
      FreeAndNil(jpeg);
    if pic <> nil then
      FreeAndNil(pic);
  end;
end;

procedure TfrmMain.TrayDblClick(Sender: TObject);
begin
  mniSpeed.Click;
end;

end.
