-- предпологается что таблица SLots будет очень большой это будет очень большая таблица
--Скрипт создания Slots_Partitioned



-- Создание новой файловой группы для хранения партиций
ALTER DATABASE BookingServices
ADD FILEGROUP PartitionSchemeFG1;
GO

-- Добавление файла в новую файловую группу
ALTER DATABASE BookingServices
ADD FILE
(
    NAME = PartitionFile2,
    FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQL\DATA\PartitionFileSlots.ndf',
    SIZE = 5MB,
    MAXSIZE = UNLIMITED,
    FILEGROWTH = 5MB
)
TO FILEGROUP PartitionSchemeFG1;
GO

-- Создание схемы партиционирования
CREATE PARTITION FUNCTION DateRangePF (datetime2(0))
AS RANGE LEFT FOR VALUES ('2023-01-01', '2023-02-01', '2023-03-01', '2023-04-01');
GO

-- Создание схемы схемы партиционирования
CREATE PARTITION SCHEME DateRangePS
AS PARTITION DateRangePF
TO (PartitionSchemeFG1, PartitionSchemeFG1, PartitionSchemeFG1, PartitionSchemeFG1, PartitionSchemeFG1);
GO

-- Создание партиционированной таблицы
CREATE TABLE [dbo].[Slots_Partitioned]
(
	[SlotID] [int] NOT NULL,
	[SlotName] [nvarchar](150) NULL,
	[ServiceСenterID] [bigint] NULL,
	[ServiceGroupID] [bigint] NULL,
	[ServiceItemsID] [bigint] NULL,
	[ServiceProducerID] [int] NULL,
	[Date] [date] NULL,
	[StartTime] [time](7) NULL,
	[EndTime] [time](7) NULL,
	[AvailableCapacity] [int] NULL,
	[Description] [nvarchar](150) NULL
) ON DateRangePS(Date);
GO

-- Создание индекса на партиционированной таблице
CREATE CLUSTERED INDEX CIX_Slots_Partitioned ON Slots_Partitioned(SlotID) ON DateRangePS(Date);
GO

-- скрипт заполнения
INSERT INTO dbo.Slots_Partitioned
SELECT *
FROM dbo.Slots;
GO