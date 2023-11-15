/*Создайте очередь для формирования отчетов для клиентов по таблице Invoices. При вызове процедуры для создания отчета в очередь должна отправляться заявка.*/
--Create Message Types for Request and Reply messages

--включаем борокер
ALTER DATABASE [WideWorldImporters] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
ALTER DATABASE [WideWorldImporters] SET ENABLE_BROKER
ALTER DATABASE [WideWorldImporters] SET MULTI_USER


--создаем сообщений и контракт
USE WideWorldImporters
-- For Request
CREATE MESSAGE TYPE
[//WWI/Report/RequestMessage]
VALIDATION=WELL_FORMED_XML;
-- For Reply
CREATE MESSAGE TYPE
[//WWI/Report/ReplyMessage]
VALIDATION=WELL_FORMED_XML; 

GO

CREATE CONTRACT [//WWI/Report/Contract]
      ([//WWI/Report/RequestMessage] SENT BY INITIATOR,
       [//WWI/Report/ReplyMessage] SENT BY TARGET
      );
GO


--создаем очереди и сервисы
CREATE QUEUE TargetReportQueueWWI;

CREATE SERVICE [//WWI/Report/TargetService]
       ON QUEUE TargetReportQueueWWI
       ([//WWI/Report/Contract]);
GO


CREATE QUEUE InitiatorReportQueueWWI;

CREATE SERVICE [//WWI/Report/InitiatorService]
       ON QUEUE InitiatorReportQueueWWI
       ([//WWI/Report/Contract]);
GO


--Создаем таблицу для хранения отчетов
CREATE TABLE Reports
(
  id INT PRIMARY KEY IDENTITY(1,1),
  xml_data XML NOT NULL,
);


--Создаем хранимую процедуру формирования заявки для создания нового отчета
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE GetReport
  @CustomerID INT,
  @BeginDate date,
  @EndDate date
AS
BEGIN
  SET NOCOUNT ON;
  DECLARE @InitDlgHandle UNIQUEIDENTIFIER;
  DECLARE @RequestMessage NVARCHAR(4000);

  BEGIN TRAN

  SELECT @RequestMessage = (SELECT  @CustomerID as CustomerID, @BeginDate  as BeginDate, @EndDate as EndDate from [Sales].[Customers] Where CustomerID= @CustomerID 
    FOR XML AUTO, root('RequestMessage'));

  BEGIN DIALOG @InitDlgHandle
	FROM SERVICE
	[//WWI/Report/InitiatorService]
	TO SERVICE
	'//WWI/Report/TargetService'
	ON CONTRACT
	[//WWI/Report/Contract]
	WITH ENCRYPTION=OFF;

  SEND ON CONVERSATION @InitDlgHandle 
	MESSAGE TYPE
	[//WWI/Report/RequestMessage]
	(@RequestMessage);

  SELECT @RequestMessage AS SentRequestMessage;

  COMMIT TRAN
END
GO

/*
USE [WideWorldImporters]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[GetReport]
		@CustomerID = 832,
		@BeginDate = '20000101',
		@EndDate = '20230101'

SELECT	'Return Value' = @return_value

GO

*/


--Создаем хранимую процедуру обработки очереди TargetReportQueueWWI (создания отчетов)
/****** Object:  StoredProcedure [dbo].[CreateReport]    Script Date: 15.11.2023 18:17:06 ******/
USE [WideWorldImporters]
GO
/****** Object:  StoredProcedure [dbo].[CreateReport]    Script Date: 15.11.2023 18:17:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateReport]
AS
BEGIN

  DECLARE @TargetDlgHandle UNIQUEIDENTIFIER,
			@Message NVARCHAR(4000),
			@MessageType Sysname,
			@ReplyMessage NVARCHAR(4000),
			@CustomerID INT,
       @BeginDate date,
       @EndDate date,
       @xml XML;

  BEGIN TRAN;

  RECEIVE TOP(1)
		@TargetDlgHandle = Conversation_Handle,
		@Message = Message_Body,
		@MessageType = Message_Type_Name
	FROM dbo.TargetReportQueueWWI;

  SELECT @Message;

  SET @xml = CAST(@Message AS XML);

  SELECT
    @CustomerID = R.Iv.value('@CustomerID','INT'),
    @BeginDate = R.Iv.value('@BeginDate','DATE'),
    @EndDate = R.Iv.value('@EndDate','DATE')
  FROM @xml.nodes('/RequestMessage/Sales.Customers') as R(Iv);

  Select 
   @CustomerID as CustomerID,
    @BeginDate  as CustomerID,
   @EndDate  as EndDate 


  IF @MessageType=N'//WWI/Report/RequestMessage'
	BEGIN


    SELECT @ReplyMessage = (SELECT
        CustomerID as CustomerID,
        count(*) as Count
      FROM [WideWorldImporters].[Sales].[Orders]
      Where
        CustomerID = @CustomerID
        AND OrderDate between @BeginDate AND @EndDate
      Group By
        CustomerID
      FOR XML AUTO, root('Report'));


    SEND ON CONVERSATION @TargetDlgHandle
		MESSAGE TYPE
		[//WWI/Report/ReplyMessage]
		(@ReplyMessage);
    END CONVERSATION @TargetDlgHandle;
  END

  SELECT @ReplyMessage AS SentReplyMessage;


 COMMIT TRAN;

END



/*
USE [WideWorldImporters]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[CreateReport]

SELECT	'Return Value' = @return_value

GO

*/



--Создания хранимой процедуры считывания созданного отчета и запись его в базу данных
GO
/****** Object:  StoredProcedure [dbo].[SaveReport]    Script Date: 15.11.2023 18:23:21 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SaveReport]
AS
BEGIN
	--Receiving Reply Message from the Target.	
	DECLARE @InitiatorReplyDlgHandle UNIQUEIDENTIFIER,
			@ReplyReceivedMessage NVARCHAR(1000) 
	
	BEGIN TRAN; 

		RECEIVE TOP(1)
			@InitiatorReplyDlgHandle=Conversation_Handle
			,@ReplyReceivedMessage=Message_Body
		FROM dbo.InitiatorReportQueueWWI; 
		
		END CONVERSATION @InitiatorReplyDlgHandle; 

   INSERT INTO dbo.Reports(xml_data)
    VALUES (@ReplyReceivedMessage);

		SELECT @ReplyReceivedMessage AS ReceivedRepliedMessage; --íå äëÿ ïðîäà

	COMMIT TRAN; 
END

/*
USE [WideWorldImporters]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[SaveReport]

SELECT	'Return Value' = @return_value

GO
*/

--Проверил работу харнимым процедур файлик прикладываю


GO
ALTER QUEUE [dbo].[InitiatorReportQueueWWI] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = OFF) 
	, ACTIVATION (   STATUS = ON ,
        PROCEDURE_NAME = SaveReport, MAX_QUEUE_READERS = 1, EXECUTE AS OWNER) ; 

GO
ALTER QUEUE [dbo].[TargetReportQueueWWI] WITH STATUS = ON , RETENTION = OFF , POISON_MESSAGE_HANDLING (STATUS = OFF)
	, ACTIVATION (  STATUS = ON ,
        PROCEDURE_NAME = CreateReport, MAX_QUEUE_READERS = 1, EXECUTE AS OWNER) ; 

GO

-- все заработало!!!!!!!!!!!!!!!!