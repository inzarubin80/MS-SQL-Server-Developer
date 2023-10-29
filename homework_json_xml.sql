--В личном кабинете есть файл StockItems.xml.
--Это данные из таблицы Warehouse.StockItems.
--Преобразовать эти данные в плоскую таблицу с полями, аналогичными Warehouse.StockItems.
--Поля: StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays, IsChillerStock, TaxRate, UnitPrice
--Загрузить эти данные в таблицу Warehouse.StockItems.
--Существующие записи в таблице обновить, отсутствующие добавить (сопоставлять записи по полю StockItemName).
--Сделать два варианта: с помощью OPENXML и через XQuery.

--OPENXML

DECLARE @DocHandle int;
DECLARE @XmlDocument NVARCHAR(MAX);

SELECT @XmlDocument = BulkColumn
FROM OPENROWSET(BULK 'C:\Users\izarubin\MS SQL Server Developer\StockItems.xml', SINGLE_CLOB) AS XmlData;

EXEC sp_xml_preparedocument @DocHandle OUTPUT, @XmlDocument;

DROP TABLE IF EXISTS  #StockItems;
CREATE TABLE #StockItems
(
  StockItemName varchar(100),
  SupplierID int,
  UnitPackageID int,
  OuterPackageID int,
  QuantityPerOuter int,
  TypicalWeightPerUnit float,
  LeadTimeDays varchar(10),
  IsChillerStock [bit],
  TaxRate float,
  UnitPrice float
)

INSERT INTO #StockItems
  (StockItemName, SupplierID, UnitPackageID, OuterPackageID, QuantityPerOuter, TypicalWeightPerUnit, LeadTimeDays,
  IsChillerStock, TaxRate, UnitPrice)
SELECT StockItemName,
  SupplierID,
  UnitPackageID,
  OuterPackageID,
  QuantityPerOuter,
  TypicalWeightPerUnit,
  LeadTimeDays,
  IsChillerStock,
  TaxRate,
  UnitPrice
FROM OPENXML (@DocHandle, '/StockItems/Item',1)
      WITH (
        StockItemName varchar(100) '@Name',
        SupplierID int '(SupplierID)[1]',
        UnitPackageID int '(Package/UnitPackageID)[1]',
        OuterPackageID int '(Package/OuterPackageID)[1]',
        QuantityPerOuter int '(Package/QuantityPerOuter)[1]',
        TypicalWeightPerUnit  float '(Package/TypicalWeightPerUnit)[1]',
        LeadTimeDays varchar(10) '(LeadTimeDays)[1]',
        IsChillerStock [bit]  '(IsChillerStock)[1]' ,
        TaxRate float '(TaxRate)[1]',
        UnitPrice float '(UnitPrice)[1]'
  )
EXEC sp_xml_removedocument @DocHandle
;
MERGE INTO Warehouse.StockItems AS target  
 USING (SELECT
  StockItemName,
  SupplierID,
  UnitPackageID,
  OuterPackageID,
  QuantityPerOuter,
  TypicalWeightPerUnit,
  LeadTimeDays,
  IsChillerStock,
  TaxRate,
  UnitPrice,
  1 as LastEditedBy
from #StockItems )  as source
  ON (target.StockItemName = source.StockItemName  collate Cyrillic_General_CI_AS ) 
  WHEN MATCHED THEN
    UPDATE SET
        target.[StockItemName] = source.[StockItemName],
        target.[SupplierID] = source.[SupplierID],
        target.[UnitPackageID] = source.[UnitPackageID],
        target.[OuterPackageID] = source.[OuterPackageID],
        target.[QuantityPerOuter] = source.[QuantityPerOuter],
        target.[TypicalWeightPerUnit] = source.[TypicalWeightPerUnit],
        target.[LeadTimeDays] = source.[LeadTimeDays],
        target.[IsChillerStock] = source.[IsChillerStock],
        target.[TaxRate] = source.[TaxRate],
        target.[UnitPrice] = source.[UnitPrice],
        target.[LastEditedBy] = source.[LastEditedBy]
        WHEN NOT MATCHED THEN
        INSERT (
  StockItemName, 
  SupplierID, 
  UnitPackageID, 
  OuterPackageID, 
  QuantityPerOuter,
  TypicalWeightPerUnit,
  LeadTimeDays,
  IsChillerStock,
  TaxRate,
  UnitPrice,
  LastEditedBy
    )
    VALUES (
    source.StockItemName, 
   source.SupplierID, 
   source.UnitPackageID, 
   source.OuterPackageID, 
   source.QuantityPerOuter,
   source.TypicalWeightPerUnit,
   source.LeadTimeDays,
   source.IsChillerStock,
   source.TaxRate,
   source.UnitPrice,
   source.LastEditedBy

    );


--XQuery
DROP TABLE IF EXISTS  #StockItems;

CREATE TABLE #StockItems
(
  StockItemName varchar(100),
  SupplierID int,
  UnitPackageID int,
  OuterPackageID int,
  QuantityPerOuter int,
  TypicalWeightPerUnit float,
  LeadTimeDays varchar(10),
  IsChillerStock [bit],
  TaxRate float,
  UnitPrice float
);

DECLARE @xml XML;
SET @xml = (SELECT *
FROM OPENROWSET(BULK 'C:\Users\izarubin\MS SQL Server Developer\StockItems.xml', SINGLE_CLOB) AS xmlData);
INSERT INTO #StockItems
SELECT
  t.value('(StockItemName)[1]', 'NVARCHAR(100)'),
  t.value('(SupplierID)[1]', 'INT'),
  t.value('(UnitPackageID)[1]', 'INT'),
  t.value('(OuterPackageID)[1]', 'INT'),
  t.value('(QuantityPerOuter)[1]', 'DECIMAL(18,2)'),
  t.value('(TypicalWeightPerUnit)[1]', 'DECIMAL(18,2)'),
  t.value('(LeadTimeDays)[1]', 'INT'),
  t.value('(IsChillerStock)[1]', 'BIT'),
  t.value('(TaxRate)[1]', 'DECIMAL(18,2)'),
  t.value('(UnitPrice)[1]', 'DECIMAL(18,2)')
FROM @xml.nodes('/Root/StockItem') AS x(t);


MERGE INTO Warehouse.StockItems AS target  
 USING (SELECT
  StockItemName,
  SupplierID,
  UnitPackageID,
  OuterPackageID,
  QuantityPerOuter,
  TypicalWeightPerUnit,
  LeadTimeDays,
  IsChillerStock,
  TaxRate,
  UnitPrice,
  1 as LastEditedBy
from #StockItems )  as source
  ON (target.StockItemName = source.StockItemName  collate Cyrillic_General_CI_AS ) 
  WHEN MATCHED THEN
    UPDATE SET
        target.[StockItemName] = source.[StockItemName],
        target.[SupplierID] = source.[SupplierID],
        target.[UnitPackageID] = source.[UnitPackageID],
        target.[OuterPackageID] = source.[OuterPackageID],
        target.[QuantityPerOuter] = source.[QuantityPerOuter],
        target.[TypicalWeightPerUnit] = source.[TypicalWeightPerUnit],
        target.[LeadTimeDays] = source.[LeadTimeDays],
        target.[IsChillerStock] = source.[IsChillerStock],
        target.[TaxRate] = source.[TaxRate],
        target.[UnitPrice] = source.[UnitPrice],
        target.[LastEditedBy] = source.[LastEditedBy]
        WHEN NOT MATCHED THEN
        INSERT (
  StockItemName, 
  SupplierID, 
  UnitPackageID, 
  OuterPackageID, 
  QuantityPerOuter,
  TypicalWeightPerUnit,
  LeadTimeDays,
  IsChillerStock,
  TaxRate,
  UnitPrice,
  LastEditedBy
    )
    VALUES (
    source.StockItemName, 
   source.SupplierID, 
   source.UnitPackageID, 
   source.OuterPackageID, 
   source.QuantityPerOuter,
   source.TypicalWeightPerUnit,
   source.LeadTimeDays,
   source.IsChillerStock,
   source.TaxRate,
   source.UnitPrice,
   source.LastEditedBy
    );


--   Выгрузить данные из таблицы StockItems в такой же xml-файл, как StockItems.xml
--Примечания к заданиям 1, 2:
--Если с выгрузкой в файл будут проблемы, то можно сделать просто SELECT c результатом в виде XML.
--Если у вас в проекте предусмотрен экспорт/импорт в XML, то можете взять свой XML и свои таблицы.
--Если с этим XML вам будет скучно, то можете взять любые открытые данные и импортировать их в таблицы (например, с https://data.gov.ru).
--Пример экспорта/импорта в файл https://docs.microsoft.com/en-us/sql/relational-databases/import-export/examples-of-bulk-import-and-export-of-xml-documents-sql-server


-- Запись XML-данных в файл с помощью bcp
--ответ
 BCP "SELECT * FROM Warehouse.StockItems FOR XML PATH('StockItem'), ROOT('Root')" queryout "C:\Program Files\Microsoft SQL Server\MSSQL16.SQL2022\MSSQL\DATA\StockItemsOut.xml" -w -r -T -S "NB-PF3728FS\SQL2022" -d "WideWorldImporters"
-- есть проблемы с экранированием но мне кажется не суть этой задачи :)



-- таблице Warehouse.StockItems в колонке CustomFields есть данные в JSON.
--Написать SELECT для вывода:
--StockItemID
--StockItemName
--CountryOfManufacture (из CustomFields)
--FirstTag (из поля CustomFields, первое значение из массива Tags)
SELECT 
    StockItemID,
    StockItemName,
    JSON_VALUE(CustomFields, '$.CountryOfManufacture') AS CountryOfManufacture,
    JSON_VALUE(CustomFields, '$.Tags[0]') AS FirstTag
FROM Warehouse.StockItems

/*
Найти в StockItems строки, где есть тэг "Vintage".
Вывести:
StockItemID
StockItemName
(опционально) все теги (из CustomFields) через запятую в одном поле
Тэги искать в поле CustomFields, а не в Tags.
Запрос написать через функции работы с JSON.
Для поиска использовать равенство, использовать LIKE запрещено.
Должно быть в таком виде:
... where ... = 'Vintage'
Так принято не будет:
... where ... Tags like '%Vintage%'
... where ... CustomFields like '%Vintage%'
*/

SELECT StockItemID, StockItemName, JSTag.value as Tag
FROM [Warehouse].[StockItems]
CROSS APPLY OPENJSON(CustomFields, '$.Tags') as JSTag
where
JSTag.value = 'Vintage'
