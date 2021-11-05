GO
USE Larabox

--1
GO
CREATE TRIGGER TR_NUEVA_SUSCRIPCION ON Suscripciones
INSTEAD OF INSERT
AS
BEGIN 
	BEGIN TRY
		DECLARE @ID_UsuarioInserted BIGINT
		DECLARE @ID_TipoCuentaInserted INT
		SELECT  @ID_TipoCuentaInserted = IDTipoCuenta, @ID_UsuarioInserted = IDUsuario FROM inserted
		
		DECLARE @ID_TipoCuenta INT
		IF(SELECT COUNT(*) FROM Suscripciones WHERE IDUsuario = @ID_UsuarioInserted AND Fin IS NULL) > 0 BEGIN
			RAISERROR('te llevo directo al catch',16,1)
			/*
			SELECT @ID_TipoCuenta = IDTipoCuenta FROM Suscripciones WHERE IDUsuario = @ID_UsuarioInserted AND Fin IS NULL
			IF (@ID_TipoCuenta = @ID_UsuarioInserted) BEGIN
				UPDATE Suscripciones SET Fin = GETDATE() WHERE IDUsuario = @ID_UsuarioInserted AND Fin IS NULL				
			END
			*/
		END
		ELSE BEGIN 
			INSERT INTO Suscripciones (IDUsuario,IDTipoCuenta,Inicio)
			SELECT IDUsuario, IDTipoCuenta, Inicio FROM inserted
		END
	END TRY
	BEGIN CATCH
		RAISERROR('ERROR AL INSERTAR EL USUARIO YA POSEE UN TIPO DE CUENTA VIGENTE IGUAL A LA ACTUAL',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 2
------------------------------
INSERT INTO Pagos (IDSuscripcion,IDFormaPago,Fecha,Mes,Año,Importe) VALUES
(2,1,GETDATE(),8,2018,100.00)

select * from Pagos where IDSuscripcion = 2
select * from TiposCuenta where ID = 2
select * from Suscripciones where ID=2
------------------------------
------------------------------
--2
CREATE TRIGGER TR_INSERTAR_PAGO ON Pagos
INSTEAD OF INSERT 
AS
BEGIN
	DECLARE @ERROR INT
	BEGIN TRY
		BEGIN TRANSACTION

			DECLARE @ID_Suscripcion BIGINT 
			DECLARE @mes TINYINT
			DECLARE @año SMALLINT
			DECLARE @importe MONEY
			SELECT @ID_Suscripcion=IDSuscripcion,@mes=Mes, @año=Año,@importe=Importe FROM inserted
			IF(SELECT COUNT(*) FROM Pagos WHERE IDSuscripcion=@ID_Suscripcion AND Año=@año AND Mes=@mes) > 0 BEGIN
				SET @ERROR = 1
				RAISERROR('al catch',16,1)
			END

			DECLARE @ID_TipoCuenta INT	
			SELECT @ID_TipoCuenta=IDTipoCuenta FROM Suscripciones WHERE ID=@ID_Suscripcion
			DECLARE @costoTipoCuenta MONEY
			SELECT @costoTipoCuenta=Costo FROM TiposCuenta WHERE ID=@ID_TipoCuenta
			IF @costoTipoCuenta = @importe BEGIN
				INSERT INTO Pagos (IDSuscripcion,IDFormaPago,Fecha,Mes,Año,Importe)
				SELECT IDSuscripcion,IDFormaPago,GETDATE(),Mes,Año,Importe FROM inserted
			END
			ELSE BEGIN
				SET @ERROR = 2
				RAISERROR('al catch',16,1)
			END
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		IF @ERROR = 1 BEGIN
			RAISERROR('YA EXISTE UN PAGO DE ESA FECHA',16,1)
		END
		IF @ERROR = 2 BEGIN
			RAISERROR('EL PAGO NO COINCIDE CON EL IMPORTE DE EL TIPO DE CUENTA',16,1)
		END
	END CATCH
END

------------------------------
--TO TEST ejercicio 3
------------------------------
INSERT INTO Suscripciones (IDUsuario,IDTipoCuenta,Inicio) VALUES 
(1,2,'10-11-2021')

SELECT * FROM Suscripciones WHERE IDUsuario=1
DELETE FROM Suscripciones WHERE ID = 38

------------------------------
------------------------------
--3
ALTER TRIGGER TR_NUEVA_SUSCRIPCION ON Suscripciones
INSTEAD OF INSERT
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @ID_Usuario BIGINT
			SELECT @ID_Usuario=IDUsuario FROM inserted
			IF(SELECT COUNT(*) FROM Suscripciones WHERE IDUsuario=@ID_Usuario AND Fin IS NULL) > 0 BEGIN
				UPDATE Suscripciones SET Fin = GETDATE() WHERE IDUsuario=@ID_Usuario AND Fin IS NULL
			END
			INSERT INTO Suscripciones (IDUsuario,IDTipoCuenta,Inicio)
			SELECT IDUsuario,IDTipoCuenta,GETDATE() FROM inserted
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('ERROR AL ....',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 4
------------------------------
INSERT INTO Archivos (IDUsuario,Nombre,Extension,Tamaño,Creacion,Estado) VALUES
(2,'TEST','XLS',143360,'10-10-2000',1)

SELECT * FROM Usuarios WHERE Estado = 0

UPDATE Usuarios SET Estado=1 WHERE ID=2

select * from TiposCuenta

UPDATE Suscripciones SET IDTipoCuenta = 2 WHERE IDUsuario = 2

SELECT u.ID,u.Estado AS [Estado Usuario], SUM(a.Tamaño/1024),tc.Cuota,tc.Nombre,tc.ID AS [ID tipo cuenta],s.ID AS [id suscripcion]
FROM Archivos AS a
INNER JOIN Usuarios AS u ON u.ID = a.IDUsuario
INNER JOIN Suscripciones AS s ON s.IDUsuario=u.ID
INNER JOIN TiposCuenta AS tc ON tc.ID = s.IDTipoCuenta
WHERE u.ID = 2 AND s.Fin IS NULL
GROUP BY u.ID, u.Estado, tc.Cuota,tc.Nombre,tc.ID,s.ID

SELECT * FROM Archivos AS a
INNER JOIN Usuarios AS u ON u.ID = a.IDUsuario
WHERE u.ID = 2
ORDER BY a.ID DESC

DELETE FROM Archivos WHERE ID=109

------------------------------
------------------------------

--4
ALTER TRIGGER TR_INSERTAR_ARCHIVO ON Archivos 
INSTEAD OF INSERT
AS
BEGIN
	DECLARE @ERROR INT
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @ID_Usuario BIGINT
			DECLARE @tamañoInserted BIGINT
			SELECT @ID_Usuario=IDUsuario, @tamañoInserted=Tamaño/1024 FROM inserted
			
			IF(SELECT COUNT(*) FROM Usuarios WHERE ID=@ID_Usuario AND Estado=0) > 0 BEGIN
				SET @ERROR = 1
				RAISERROR('',16,1)
			END
			
			DECLARE @tamañoTodosArchivos BIGINT
			SELECT @tamañoTodosArchivos = SUM(Tamaño/1024) FROM Archivos WHERE IDUsuario=@ID_Usuario AND Estado = 1
			DECLARE @cuota INT
			SELECT @cuota=tc.Cuota FROM Suscripciones AS s 
			INNER JOIN TiposCuenta AS tc ON tc.ID = s.IDTipoCuenta
			WHERE s.IDUsuario=@ID_Usuario AND s.Fin IS NULL

			SET @tamañoTodosArchivos += @tamañoInserted
			IF @tamañoTodosArchivos > @cuota BEGIN
				SET @ERROR = 2
				RAISERROR('',16,1)
			END

			INSERT INTO Archivos (IDUsuario,Nombre,Extension,Tamaño,Creacion,Estado)
			SELECT IDUsuario,Nombre,Extension,Tamaño,GETDATE(),1 FROM inserted

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		IF @ERROR = 1 BEGIN
			RAISERROR('ERROR - EL USUARIO ESTA DADO DE BAJA',16,1)
		END
		IF @ERROR = 2 BEGIN
			RAISERROR('ERROR - EL TAMAÑO EXCEDE EL LIMITE PERMITIDO POR LA CUOTA DEL TIPO DE CUENTA',16,1)
		END
	END CATCH
END

------------------------------
--TO TEST ejercicio 5
------------------------------
DELETE FROM Archivos WHERE ID=1

SELECT * FROM Archivos WHERE ID=1

------------------------------
------------------------------

--5
CREATE TRIGGER TR_ARCHIVO_BAJA_LOGICA ON Archivos 
INSTEAD OF DELETE 
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @ID_Archivo BIGINT
			SELECT @ID_Archivo=ID FROM deleted

			UPDATE Archivos SET Estado=0 WHERE ID = @ID_Archivo

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('ERROR AL ELIMINAR',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 6
------------------------------
DELETE FROM Usuarios WHERE ID=2

SELECT * FROM Usuarios AS u
INNER JOIN Archivos AS a ON a.IDUsuario=u.ID
WHERE u.ID=2

UPDATE Usuarios SET Estado = 1 WHERE ID=2
UPDATE Archivos SET Estado = 1 WHERE IDUsuario=2
------------------------------
------------------------------

--6
CREATE TRIGGER TR_BAJA_LOGICA_USUARIO ON Usuarios
INSTEAD OF DELETE
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @ID_Usuario BIGINT
			SELECT @ID_Usuario = ID FROM deleted

			UPDATE Usuarios SET Estado = 0 WHERE ID=@ID_Usuario
			UPDATE Archivos SET Estado = 0 WHERE IDUsuario=@ID_Usuario

		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('ERROR AL ELIMINAR',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 7
------------------------------
DELETE FROM Archivos WHERE ID=1

SELECT * FROM Archivos WHERE ID = 1

UPDATE Archivos SET Estado = 0 WHERE ID=1

SELECT * FROM Archivos AS a
INNER JOIN Usuarios AS u ON u.ID=a.IDUsuario
WHERE u.ID=15

INSERT INTO Archivos(IDUsuario,Nombre,Extension,Tamaño,Creacion,Modificacion,Estado)VALUES
(15,'UtAt','jpeg',55296,'2021-03-16','2021-06-19',1)
------------------------------
------------------------------

--7
CREATE TRIGGER TR_ELIMINAR_LOS_BAJA_LOGICA ON Archivos
INSTEAD OF DELETE 
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @ID_Archivo BIGINT
			SELECT @ID_Archivo = ID FROM deleted
			IF(SELECT COUNT(*) FROM Archivos WHERE ID=@ID_Archivo AND Estado = 0) >0 BEGIN
				DELETE FROM Archivos WHERE ID=@ID_Archivo
			END
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('ERROR AL ELIMINAR',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 8
------------------------------

DELETE FROM Usuarios WHERE ID=19

SELECT COUNT(*) AS [CANTIDAD DE ARCHIVOS], u.Nombreusuario,u.ID
FROM Archivos AS a
INNER JOIN Usuarios AS u ON u.ID = a.IDUsuario
GROUP BY u.Nombreusuario,u.ID
SELECT * FROM Archivos WHERE ID = 1

SELECT * FROM Usuarios WHERE ID=19

SELECT * FROM Usuarios AS u
INNER JOIN Archivos AS a ON a.IDUsuario=u.ID
WHERE u.ID=19

------------------------------
------------------------------

--8
CREATE TRIGGER ELIMINAR_USUARIO_CON_BAJA_LOGICA ON Usuarios
INSTEAD OF DELETE
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION 
			DECLARE @ID_Usuario BIGINT
			SELECT @ID_Usuario = ID FROM deleted
			IF(SELECT COUNT(*) FROM Usuarios WHERE ID=@ID_Usuario AND Estado=0) > 0 BEGIN
				DELETE FROM Usuarios WHERE ID=@ID_Usuario
				DELETE FROM Archivos WHERE IDUsuario = @ID_Usuario
			END
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION

		RAISERROR('NO SE PUDO ELIMINAR USUARIO',16,1)
	END CATCH
END

------------------------------
--TO TEST ejercicio 9
------------------------------

INSERT INTO TiposCuenta (Nombre,Cuota,Costo) VALUES
('TEST',7500,600.00)

SELECT * FROM TiposCuenta

DELETE FROM TiposCuenta WHERE ID=15
------------------------------
------------------------------

--9
ALTER TRIGGER TR_INSERTAR_TIPO_CUOTA ON TiposCuenta
INSTEAD OF INSERT
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @costoInserted MONEY
			DECLARE @cuotaInserted INT
			SELECT @costoInserted=Costo,@cuotaInserted = Cuota FROM inserted
			

			
				
				DECLARE @costo MONEY
				DECLARE @cuota INT

				IF(SELECT @costo=Costo,@cuota=Cuota FROM TiposCuenta) BEGIN
					IF @cuota >= @cuotaInserted BEGIN
						IF @costoInserted > @costo BEGIN
							RAISERROR('',16,1)
						END
					END
				END

			
			INSERT INTO TiposCuenta (Nombre,Cuota,Costo)
			SELECT Nombre,Cuota,Costo FROM inserted
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('Tipo de cuenta no conveniente',16,1)
	END CATCH
END








/*
ALTER TRIGGER TR_INSERTAR_TIPO_CUOTA ON TiposCuenta
INSTEAD OF INSERT
AS
BEGIN
	BEGIN TRY
		BEGIN TRANSACTION
			DECLARE @costoInserted MONEY
			DECLARE @cuotaInserted INT
			SELECT @costoInserted=Costo,@cuotaInserted = Cuota FROM inserted
			
			DECLARE @CONTADOR INT
			SET @CONTADOR = 0
			DECLARE @CANTIDAD INT
			SELECT @CANTIDAD=COUNT(*) FROM TiposCuenta

			WHILE @CONTADOR < @CANTIDAD  BEGIN
				SET @CONTADOR = @CONTADOR + 1
				DECLARE @costo MONEY
				DECLARE @cuota INT
				SELECT @costo=Costo,@cuota=Cuota FROM TiposCuenta WHERE ID = @CONTADOR

				IF @cuota >= @cuotaInserted BEGIN
					IF @costoInserted > @costo BEGIN
						RAISERROR('',16,1)
					END
				END
			END
			INSERT INTO TiposCuenta (Nombre,Cuota,Costo)
			SELECT Nombre,Cuota,Costo FROM inserted
		COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION
		RAISERROR('Tipo de cuenta no conveniente',16,1)
	END CATCH
END
*/