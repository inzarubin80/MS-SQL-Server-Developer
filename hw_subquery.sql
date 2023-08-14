/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/
WITH
    SalesPerson_CTE
    AS
    (
        SELECT
            People.PersonID,
            People.FullName
        FROM Application.People as People
        where 
    People.IsSalesPerson = 1
    )

SELECT
    SalesPerson.PersonID,
    SalesPerson.FullName
from SalesPerson_CTE as SalesPerson
WHERE NOT EXISTS (
    select Invoices.InvoiceID
FROM
    Sales.Invoices as Invoices
WHERE 
    Invoices.SalespersonPersonID = SalesPerson.PersonID
    AND Invoices.InvoiceDate = '2015-07-04'
)

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

--Вариант1 CTE

WITH
    MinPrice_CTE
    AS
    (
        SELECT
            MIN(StockItems.UnitPrice) as UnitPrice
        from Warehouse.StockItems as StockItems
    )

SELECT
    StockItems.StockItemID,
    StockItemName,
    StockItems.UnitPrice
from Warehouse.StockItems as StockItems
WHERE 
StockItems.UnitPrice in (Select MinPriceCTE.UnitPrice
from MinPrice_CTE as MinPriceCTE)
;

--Вариант2 подзапрос
SELECT
    StockItems.StockItemID,
    StockItemName,
    StockItems.UnitPrice
from Warehouse.StockItems as StockItems
WHERE 
StockItems.UnitPrice in ( SELECT
    MIN(StockItems.UnitPrice) as UnitPrice
from Warehouse.StockItems as StockItems)

--Вариант3 переменная
DECLARE @MinUnitPrice DECIMAL(18,2);

SELECT
    @MinUnitPrice = MIN(StockItems.UnitPrice)
from Warehouse.StockItems as StockItems

SELECT
    StockItems.StockItemID,
    StockItemName,
    StockItems.UnitPrice
from Warehouse.StockItems as StockItems
WHERE 
StockItems.UnitPrice =  @MinUnitPrice


--Вариант4 временная таблица
CREATE TABLE #MinUnitPrice
(
    UnitPrice decimal(18, 2) NOT NULL
);

INSERT INTO #MinUnitPrice
    (UnitPrice)
SELECT
    MIN(StockItems.UnitPrice) as UnitPrice
from Warehouse.StockItems as StockItems
SELECT
    StockItems.StockItemID,
    StockItemName,
    StockItems.UnitPrice
from Warehouse.StockItems as StockItems
    join #MinUnitPrice  as MinUnitPrice on 
MinUnitPrice.UnitPrice = StockItems.UnitPrice

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/
;

--Вариант 1 CTE
WITH
    MaxCustomerTransactions_CTE
    as
    (
        SELECT DISTINCT *
        from (SELECT TOP 5 WITH TIES
                CustomerTransactions.TransactionAmount,
                CustomerTransactions.CustomerID
            FROM Sales.CustomerTransactions as CustomerTransactions
            Order by
  CustomerTransactions.TransactionAmount DESC) as tab
    )

Select
    MaxCustomerTransactions.CustomerID,
    MaxCustomerTransactions.TransactionAmount,
    Customers.CustomerName
from MaxCustomerTransactions_CTE as MaxCustomerTransactions
    left JOIN
    Sales.Customers as Customers
    on MaxCustomerTransactions.CustomerID = Customers.CustomerID
order BY MaxCustomerTransactions.TransactionAmount

;
--Вариант 2 временная табица
CREATE TABLE #MaxCustomerTransactions
(
    [CustomerID] [int] NOT NULL,
    [TransactionAmount] [decimal](18, 2) NOT NULL
)

INSERT INTO #MaxCustomerTransactions
    (CustomerID, TransactionAmount)
SELECT DISTINCT TransactionAmount, CustomerID
from (SELECT TOP 5 WITH TIES
        CustomerTransactions.TransactionAmount,
        CustomerTransactions.CustomerID
    FROM Sales.CustomerTransactions as CustomerTransactions
    Order by
  CustomerTransactions.TransactionAmount DESC) as tab

Select
    MaxCustomerTransactions.CustomerID,
    MaxCustomerTransactions.TransactionAmount,
    Customers.CustomerName
from #MaxCustomerTransactions as MaxCustomerTransactions
    left JOIN
    Sales.Customers as Customers
    on MaxCustomerTransactions.CustomerID = Customers.CustomerID
order BY MaxCustomerTransactions.TransactionAmount

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

CREATE TABLE #MaxPriceStockItem
(
    [StockItemID] [int] NOT NULL,

)

INSERT INTO #MaxPriceStockItem
    (StockItemID)
Select TOP 3 WITH TIES
    StockItems.StockItemID
from Warehouse.StockItems as StockItems
ORDER BY
StockItems.UnitPrice

SELECT
    CityID,
    MAX(CityName) as CityName,
    STRING_AGG(FullName, ', ') as FullName
from
    (SELECT DISTINCT
        Cities.CityID,
        Cities.CityName,
        People.FullName
    From

        Sales.Orders as Orders
        JOIN Sales.OrderLines as OrderLines
        on Orders.OrderID = OrderLines.OrderID

        JOIN #MaxPriceStockItem as MaxPriceStockItemas
        on  OrderLines.StockItemID = MaxPriceStockItemas.StockItemID

        Left JOIN Sales.Customers as Customers
        on  Orders.CustomerID = Customers.CustomerID

        Left JOIN Application.Cities as Cities
        on  Customers.DeliveryCityID = Cities.CityID

        left join Application.People as People
        on People.PersonID = Orders.PickedByPersonID) as tab

GROUP BY 
CityID
ORDER BY
CityName
DROP TABLE #MaxPriceStockItem;

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос



SELECT
    Invoices.InvoiceID,
    Invoices.InvoiceDate,
    (SELECT People.FullName
    FROM Application.People
    WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
    SalesTotals.TotalSumm AS TotalSummByInvoice,
    (SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
    FROM Sales.OrderLines
    WHERE OrderLines.OrderId = (SELECT Orders.OrderId
    FROM Sales.Orders
    WHERE Orders.PickingCompletedWhen IS NOT NULL
        AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices
    JOIN
    (SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
    FROM Sales.InvoiceLines
    GROUP BY InvoiceId
    HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
    ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC


--частично сделал, по перфомансу это быстрее на порядок 
--(убрал соединение с вложенным запросом)
--(для красоты заменил вложенный запрос в SELECT на левое соединение) 

CREATE TABLE #SalesTotals
(
    InvoiceId [int] NOT NULL,
    TotalSumm [decimal](18, 2) NOT NULL
)
CREATE CLUSTERED INDEX InvoiceId ON #SalesTotals(InvoiceId);

INSERT INTO #SalesTotals
    (InvoiceId, TotalSumm)
SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
FROM Sales.InvoiceLines
GROUP BY InvoiceId
HAVING SUM(Quantity*UnitPrice) > 27000

SELECT
    Invoices.InvoiceID,
    Invoices.InvoiceDate,
    People.FullName as SalesPersonName,
    SalesTotals.TotalSumm AS TotalSummByInvoice,
    (SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
    FROM Sales.OrderLines
    WHERE OrderLines.OrderId = (SELECT Orders.OrderId
    FROM Sales.Orders
    WHERE Orders.PickingCompletedWhen IS NOT NULL
        AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices
    left join
    Application.People as People on 
People.PersonID = Invoices.SalespersonPersonID

    JOIN #SalesTotals  AS SalesTotals
    ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC
