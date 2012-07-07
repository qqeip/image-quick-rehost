unit UntMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Buttons,
  Vcl.ToolWin, Vcl.ImgList, Vcl.ExtCtrls, clMultiDC, clMultiUploader,
  clHttpRequest, Vcl.ExtDlgs, Vcl.Menus, clConnection,clDCUtils,Clipbrd;

type
  TForm1 = class(TForm)
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
  private
    { Private declarations }
    ForceClose:Boolean;
    procedure CompleteRequest(HttpRequest: TclHttpRequest;
      const fileName: string);
    procedure AddUploadItem(const fileName: string;isFromClipboard:Boolean=false);
    procedure DoRealClose();
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

resourcestring
  defaultUA =
    'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Win64; x64; Trident/5.0)';
  defaultHost='http://localhost/imghost/api.php';
implementation

{$R *.dfm}
{ TForm1 }

procedure TForm1.AddUploadItem(const fileName: string; isFromClipboard:Boolean=false);
var
  uploadItem: TclUploadItem;
  listItem:TListItem;
begin
  uploadItem := muUploader.UploadList.add;
  uploadItem.RequestMethod := 'POST';
  uploadItem.UseHttpRequest := True;
  if (not Assigned(uploadItem.HttpRequest)) then
    uploadItem.HttpRequest := TclHttpRequest.Create(nil);
  CompleteRequest(uploadItem.HttpRequest, fileName);
  listItem:=lvQueue.Items.Add;
  with listItem do
  begin
     Caption := fileName;
     SubItems.Append('未知');
     SubItems.Append(FormatDateTime('hh:mm:ss',Now()));
     SubItems.Append('排队');
  end;
  uploadItem.Data := listItem;
  listItem.Data := uploadItem;
  uploadItem.URL:=defaultHost;
  uploadItem.Start();
end;

procedure TForm1.btnAddClick(Sender: TObject);
var
  i: LongInt;
begin
  if (dlgOpen.Execute(Handle)) then
  begin
    for i := 0 to dlgOpen.Files.Count - 1 do
      AddUploadItem(dlgOpen.Files.Strings[i]);
  end;
end;

procedure TForm1.btnQuitClick(Sender: TObject);
begin
  DoRealClose();
end;

procedure TForm1.CompleteRequest(HttpRequest: TclHttpRequest;
  const fileName: string);
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
  fileSubmitItem := HttpRequest.AddSubmitFile('image', fileName);
  fileSubmitItem.FieldName := 'image';
  fileSubmitItem.fileName := fileName; // Strange but I have to do so

end;

procedure TForm1.DoRealClose;
begin
  ForceClose:=true;
  if (muUploader.IsBusy) then
    ForceClose:= (MessageBox(Handle, '有任务正在进行，您确定要放弃所有任务并退出吗？', '退出',
      MB_YESNO + MB_ICONQUESTION) = IDYES);
  Close();
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  muUploader.Stop;
  Tray.Visible:=false;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := ForceClose;
  if (not CanClose) then
     Hide;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  muUploader.InternetAgent := defaultUA;
  ForceClose:=False;
end;

procedure TForm1.lvQueueDblClick(Sender: TObject);
begin
  if (lvQueue.Selected=nil) then
    exit;
  mniCopyClick(mniCopy);
end;

procedure TForm1.mniCopyClick(Sender: TObject);
begin
  if (lvQueue.Selected.SubItems[0]<>'未知') then
    clipboard.SetTextBuf(PCHAR(lvQueue.Selected.SubItems[0]))
  else
    MessageBox(Handle, '没有可以复制的链接', '警告', MB_OK + MB_ICONWARNING);

end;

procedure TForm1.mniLockToolbarClick(Sender: TObject);
begin
  tlbMain.Customizable := not(Sender as TMenuItem).Checked;
end;

procedure TForm1.mniQuitClick(Sender: TObject);
begin
  DoRealClose;
end;

procedure TForm1.mniShowCaptionClick(Sender: TObject);
begin
  tlbMain.ShowCaptions := (Sender as TMenuItem).Checked;
end;

procedure TForm1.mniShowWindowClick(Sender: TObject);
begin
  Visible:=not Visible;
end;

procedure TForm1.muUploaderDataItemProceed(Sender: TObject;
  Item: TclInternetItem; ResourceInfo: TclResourceInfo;
  AStateItem: TclResourceStateItem; CurrentData: PAnsiChar;
  CurrentDataSize: Integer);
begin
  stMain.Panels[2].Text:='网络:'+inttostr(Round(AStateItem.ResourceState.Speed / 1024))+'KB/s';
  TListItem(Item.Data).SubItems[2]:=IntToStr(round(AStateItem.ResourceState.BytesProceed/AStateItem.ResourceState.ResourceSize));
end;

procedure TForm1.pmListPopup(Sender: TObject);
begin
  pmList.Items[0].Enabled:=lvQueue.Selected<>nil;
end;

end.
