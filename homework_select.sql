/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, JOIN".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД WideWorldImporters можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/download/wide-world-importers-v1.0/WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Все товары, в названии которых есть "urgent" или название начинается с "Animal".
Вывести: ИД товара (StockItemID), наименование товара (StockItemName).
Таблицы: Warehouse.StockItems.
*/

SELECT StockItemID,
    StockItemName
FROM [WideWorldImporters].[Warehouse].[StockItems]
where
 [StockItemName] Like '%urgent%' or
    [StockItemName] Like 'Animal%'

/*
2. Поставщиков (Suppliers), у которых не было сделано ни одного заказа (PurchaseOrders).
Сделать через JOIN, с подзапросом задание принято не будет.
Вывести: ИД поставщика (SupplierID), наименование поставщика (SupplierName).
Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders.
По каким колонкам делать JOIN подумайте самостоятельно.
*/

SELECT Suppliers.SupplierID
      , Suppliers.SupplierName
FROM [WideWorldImporters].[Purchasing].[Suppliers] as Suppliers
    left join [WideWorldImporters].[Purchasing].[PurchaseOrders] as Orders
    on Suppliers.SupplierID = Orders.SupplierID
Where
    Orders.SupplierID is null

/*
3. Заказы (Orders) с ценой товара (UnitPrice) более 100$ 
либо количеством единиц (Quantity) товара более 20 штук
и присутствующей датой комплектации всего заказа (PickingCompletedWhen).
Вывести:
* OrderID
* дату заказа (OrderDate) в формате ДД.ММ.ГГГГ
* название месяца, в котором был сделан заказ
* номер квартала, в котором был сделан заказ
* треть года, к которой относится дата заказа (каждая треть по 4 месяца)
* имя заказчика (Customer)
Добавьте вариант этого запроса с постраничной выборкой,
пропустив первую 1000 и отобразив следующие 100 записей.

Сортировка должна быть по номеру квартала, трети года, дате заказа (везде по возрастанию).

Таблицы: Sales.Orders, Sales.OrderLines, Sales.Customers.
*/

SELECT Orders.OrderID,
    CONVERT(varchar, Orders.OrderDate, 104) OrderDate,
    DATENAME(month, Orders.OrderDate) AS OrderMonth,
    DATEPART(quarter, OrderDate) AS OrderQuarter,
    CEILING(DATEPART(month, OrderDate) / 4.0) AS OrderThird,
    Customers.CustomerName
FROM [WideWorldImporters].[Sales].[Orders]  as Orders
    left join [Sales].[OrderLines] as OrderLines
    on Orders.OrderID = OrderLines.OrderID

    left join [Sales].[Customers] as Customers
    on Orders.CustomerID = Customers.CustomerID

Where
  (OrderLines.Quantity>20 or OrderLines.UnitPrice>100)
    and Orders.PickingCompletedWhen is  not null

ORDER by OrderQuarter, OrderThird, Orders.OrderDate
OFFSET 1000 ROWS
FETCH NEXT 100 ROWS ONLY

/*
4. Заказы поставщикам (Purchasing.Suppliers),
которые должны быть исполнены (ExpectedDeliveryDate) в январе 2013 года
с доставкой "Air Freight" или "Refrigerated Air Freight" (DeliveryMethodName)
и которые исполнены (IsOrderFinalized).
Вывести:
* способ доставки (DeliveryMethodName)
* дата доставки (ExpectedDeliveryDate)
* имя поставщика
* имя контактного лица принимавшего заказ (ContactPerson)

Таблицы: Purchasing.Suppliers, Purchasing.PurchaseOrders, Application.DeliveryMethods, Application.People.
*/

Select
    PurchaseOrders.PurchaseOrderID,
    PurchaseOrders.ExpectedDeliveryDate,
    PurchaseOrders.IsOrderFinalized,
    DeliveryMethods.DeliveryMethodName
from [Purchasing].[PurchaseOrders] as PurchaseOrders
    Left join [Application].[DeliveryMethods] as DeliveryMethods on PurchaseOrders.DeliveryMethodID = PurchaseOrders.DeliveryMethodID
where 
PurchaseOrders.ExpectedDeliveryDate between '2013-01-01' AND '2013-01-30 23:59:59'
    AND PurchaseOrders.IsOrderFinalized = 1
    AND (DeliveryMethods.DeliveryMethodName = 'Air Freight' OR DeliveryMethods.DeliveryMethodName = 'Refrigerated Air Freight')


/*
5. Десять последних продаж (по дате продажи) с именем клиента и именем сотрудника,
который оформил заказ (SalespersonPerson).
Сделать без подзапросов.
*/

SELECT Top 10
    OrderID,
    People.FullName,
    Customers.CustomerName,
    Orders.OrderDate
FROM [WideWorldImporters].[Sales].[Orders] as Orders
    left join [Application].[People] as People
    on People.PersonID = Orders.SalespersonPersonID
    left join [Sales].[Customers] as Customers
    on Orders.CustomerID = Customers.CustomerID
order by
Orders.OrderDate DESC

/*
6. Все ид и имена клиентов и их контактные телефоны,
которые покупали товар "Chocolate frogs 250g".
Имя товара смотреть в таблице Warehouse.StockItems.
*/

Select
    Customers.CustomerID,
    Customers.CustomerName,
    Customers.PhoneNumber
from Sales.Customers as Customers
where Customers.CustomerID in 
(Select DISTINCT
    Orders.CustomerID
from Sales.Orders as Orders
    join Sales.OrderLines as OrderLines
    on Orders.OrderID = OrderLines.OrderID
    join Warehouse.StockItems as StockItems
    on OrderLines.StockItemID = StockItems.StockItemID
        AND StockItems.StockItemName = 'Chocolate frogs 250g')