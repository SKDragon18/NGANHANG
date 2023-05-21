CREATE PROCEDURE [dbo].[SP_CHUYENNHANVIEN]
   @MANV NCHAR(10), @MACN NCHAR(10)
AS
BEGIN
	--TH nhan vien khong ton tai hoac da xoa
	DECLARE @TrangThaiXoa BIT
	DECLARE @CMND NCHAR(10)
	DECLARE @MAMOI NCHAR(10)
	SELECT @TrangThaiXoa=TrangThaiXoa, @CMND=CMND FROM NhanVien WHERE MANV=@MANV
	IF(@TrangThaiXoa IS NULL OR @TrangThaiXoa=1)
	BEGIN
		RAISERROR ( 'Nhan vien khong ton tai trong chi nhanh', 16, 1)
		RETURN
	END

	--TH nhan vien chua thuc hien giao dich
	IF(NOT EXISTS(SELECT * FROM GD_CHUYENTIEN WHERE MANV=@MANV)AND NOT EXISTS(SELECT * FROM GD_GOIRUT WHERE MANV=@MANV))
	BEGIN 
		--TH nhan vien da lam viec tai chi nhanh do truoc day
		IF(EXISTS(SELECT * FROM LINK0.NGANHANG.DBO.NhanVien WHERE CMND=@CMND AND MACN=@MACN))
		BEGIN
			SET XACT_ABORT ON
			BEGIN DISTRIBUTED TRANSACTION;
			DELETE FROM NhanVien WHERE MANV=@MANV
			UPDATE LINK0.NGANHANG.DBO.NhanVien SET TrangThaiXoa=0 WHERE CMND=@CMND AND MACN=@MACN
			COMMIT TRANSACTION;
			RETURN;
		END
		--TH nhan vien chua lam viec tai chi nhanh do
		UPDATE NhanVien SET MACN=@MACN WHERE MANV=@MANV
		RETURN
	END


	--TH da thuc hien giao dich
	SET XACT_ABORT ON
	BEGIN DISTRIBUTED TRANSACTION;
	UPDATE NhanVien SET TrangThaiXoa=1 WHERE MANV=@MANV;
	--TH nhan vien da lam viec tai chi nhanh do truoc day
	IF(EXISTS(SELECT * FROM LINK0.NGANHANG.DBO.NhanVien WHERE CMND=@CMND AND MACN=@MACN))
	BEGIN
		UPDATE LINK0.NGANHANG.DBO.NHANVIEN SET TrangThaiXoa=0 WHERE CMND=@CMND AND MACN=@MACN
	END
	ELSE 
	BEGIN
		--TH nhan vien chua lam viec tai chi nhanh do
		SET @MAMOI=(SELECT MAX(MANV) FROM LINK0.NGANHANG.DBO.NhanVien)
		SET @MAMOI = 'NV'+CAST((CAST(SUBSTRING(@MAMOI, 3, LEN(@MAMOI) - 2) AS INT)+1) AS VARCHAR)

		INSERT INTO LINK0.NGANHANG.DBO.NhanVien (MANV,HO,TEN,CMND,DIACHI,PHAI,SODT,MACN,TrangThaiXoa)
		SELECT @MAMOI,HO,TEN,CMND,DIACHI,PHAI,SODT,@MACN,0 FROM NhanVien WHERE MANV=@MANV
	END
	COMMIT TRANSACTION;
END
GO
/****** Object:  StoredProcedure [dbo].[SP_DANGNHAP]    Script Date: 21/5/2023 7:05:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SP_DANGNHAP]
@TENLOGIN NVARCHAR (50)
AS
DECLARE @TENUSER NVARCHAR(50)
SELECT @TENUSER=NAME FROM sys.sysusers WHERE sid = SUSER_SID(@TENLOGIN)
 
 SELECT USERNAME = @TENUSER, 
  HOTEN = (SELECT HO+ ' '+ TEN FROM NHANVIEN  WHERE MANV = @TENUSER ),
   TENNHOM= NAME
   FROM sys.sysusers 
   WHERE UID = (SELECT GROUPUID 
                 FROM SYS.SYSMEMBERS 
                   WHERE MEMBERUID= (SELECT UID FROM sys.sysusers 
                                      WHERE NAME=@TENUSER))
GO
/****** Object:  StoredProcedure [dbo].[SP_LAPNHANVIENCU]    Script Date: 21/5/2023 7:05:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SP_LAPNHANVIENCU]
@MANV NCHAR(10)
AS 
BEGIN
	DECLARE @CMND NCHAR(10)
	DECLARE @TrangThaiXoa BIT
	SET @CMND=(SELECT CMND FROM NhanVien WHERE MANV=@MANV)
	SET @TrangThaiXoa=(SELECT TrangThaiXoa FROM LINK1.NGANHANG.DBO.NhanVien WHERE CMND=@CMND)
	IF(@TrangThaiXoa = 0)
	BEGIN
		RAISERROR(N'Không thể lập lại nhân viên cũ vì nhân viên đã ở chi nhánh khác',16,1)
		RETURN
	END
	UPDATE NhanVien
	SET TrangThaiXoa=0
	WHERE MANV=@MANV

END
GO
/****** Object:  StoredProcedure [dbo].[SP_TAOLOGIN]    Script Date: 21/5/2023 7:05:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SP_TAOLOGIN]
  @LGNAME VARCHAR(50),
  @PASS VARCHAR(50),
  @USERNAME VARCHAR(50),
  @ROLE VARCHAR(50)
AS
BEGIN
  DECLARE @RET INT
  EXEC @RET= SP_ADDLOGIN @LGNAME, @PASS,'NGANHANG'
  IF (@RET =1)
	BEGIN-- LOGIN NAME BI TRUNG
		RAISERROR(N'Login name đã tồn tại',16,1)
		RETURN
	END
  EXEC @RET= SP_GRANTDBACCESS @LGNAME, @USERNAME
  IF (@RET =1)  -- USER  NAME BI TRUNG
  BEGIN
       EXEC SP_DROPLOGIN @LGNAME
       RAISERROR(N'User name đã tồn tại',16,2)
	   RETURN
  END
  EXEC sp_addrolemember @ROLE, @USERNAME
  IF @ROLE= 'NGANHANG' OR @ROLE= 'CHINHANH'
  BEGIN 
    EXEC sp_addsrvrolemember @LGNAME, 'SecurityAdmin'
  END
RETURN -- THANH CONG
END
GO
/****** Object:  StoredProcedure [dbo].[SP_XOANHANVIEN]    Script Date: 21/5/2023 7:05:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SP_XOANHANVIEN]
@MANV NCHAR(10)
AS
BEGIN
		IF(EXISTS(SELECT * FROM GD_CHUYENTIEN WHERE MANV=@MANV) OR EXISTS(SELECT * FROM GD_GOIRUT WHERE MANV=@MANV))
			UPDATE NhanVien
			SET TrangThaiXoa=1
			WHERE MANV=@MANV
		ELSE DELETE FROM NhanVien WHERE MANV=@MANV
END
GO
/****** Object:  StoredProcedure [dbo].[Xoa_Login]    Script Date: 21/5/2023 7:05:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[Xoa_Login]
  @LGNAME VARCHAR(50),
  @USRNAME VARCHAR(50)
AS
BEGIN
BEGIN TRY
  EXEC SP_DROPUSER @USRNAME
  EXEC SP_DROPLOGIN @LGNAME
END TRY
BEGIN CATCH
RAISERROR(N'Tài khoản không tồn tại',16,1)
END CATCH
END
GO