/*
В проекте имеется таблица слотов которые могут зарезервировать пользователи
CREATE TABLE [dbo].[Slots](
	[SlotID] [int] IDENTITY(1,1) NOT NULL,
	[SlotName] [nvarchar](150) NULL,
	[ServiceСenterID] [bigint] NULL,
	[ServiceGroupID] [bigint] NULL,
	[ServiceItemsID] [bigint] NULL,
	[ServiceProducerID] [int] NULL,
	[Date] [date] NULL,
	[StartTime] [time](7) NULL,
	[EndTime] [time](7) NULL,
	[AvailableCapacity] [int] NULL,
	[Description] [nvarchar](150) NULL,
PRIMARY KEY CLUSTERED 
(
	[SlotID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
  По логике приложения необходимо создать страницу в которой администратор парикмахерской будет формировать и просматривать слоты напирмер на неделю
для этих целей необходимо создать индект по полю Date и ServiceСenterID
*/

USE [BookingServices]
GO
ALTER TABLE [dbo].[Slots] ADD PRIMARY KEY CLUSTERED 
(
	[SlotID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO


/*При выполнении запроса */
SELECT [SlotID]
     ,[SlotName]
      ,[ServiceСenterID]
      ,[ServiceGroupID]
     ,[ServiceItemsID]
     ,[ServiceProducerID]
     ,[Date]
      ,[StartTime]
     ,[EndTime]
      ,[AvailableCapacity]
      ,[Description]

  FROM [BookingServices].[dbo].[Slots]
 Where 
 Date < '20231228'
 AND Date > '20231221'
 AND ServiceСenterID =1

/*Увидим в плане запроса*/
/*<Object Database="[BookingServices]" Schema="[dbo]" Table="[Slots]" Index="[IX_Slots_ServiceCenterID_Date]" IndexKind="NonClustered" Storage="RowStore" />*/


