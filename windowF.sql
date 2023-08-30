--1
-- Сделать расчет суммы продаж нарастающим итогом по месяцам с 2015 года
--(в рамках одного месяца он будет одинаковый, нарастать будет в течение времени выборки).
--Нарастающий итог должен быть без оконной функции.
WITH
    salesMonth
    AS
    (
        SELECT
            EOMONTH (Invoices.InvoiceDate, 1) as month,
            sum(Quantity * UnitPrice) as sum

        FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
            join Sales.Invoices as Invoices on
  InvoiceLines.InvoiceID = Invoices.InvoiceID
        where
   Invoices.InvoiceDate>'2015-01-01'
        group by
   EOMONTH (Invoices.InvoiceDate, 1)
    )

Select
    salesMonth1.month,
    max(salesMonth1.sum) as sumMonth,
    sum(salesMonth2.sum) as sum
from
    salesMonth as salesMonth1
    join salesMonth as salesMonth2
    on salesMonth2.month<=salesMonth1.month
Group By
	salesMonth1.month
order by
	salesMonth1.month

--2
--Сделайте расчет суммы нарастающим итогом в предыдущем запросе с помощью оконной функции.
--Сравните производительность запросов 1 и 2 с помощью set statistics time, io on
;
WITH
    salesMonth
    AS
    (
        SELECT
            EOMONTH (Invoices.InvoiceDate, 1) as month,
            sum(Quantity * UnitPrice) as sum

        FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
            join Sales.Invoices as Invoices on
  InvoiceLines.InvoiceID = Invoices.InvoiceID
        where
   Invoices.InvoiceDate>'2015-01-01'
        group by
   EOMONTH (Invoices.InvoiceDate, 1)
    )


SELECT
    salesMonth.month as month,
    Sum( salesMonth.sum ) OVER (PARTITION BY 1  ORDER BY salesMonth.month )  as sum
FROM salesMonth as salesMonth
order by 
    salesMonth.month
;
--3	
--Вывести список 2х самых популярных продуктов (по количеству проданных)
--в каждом месяце за 2016 год (по 2 самых популярных продукта в каждом месяце).
Select
    SalesRank.StockItemID,
    SalesRank.month,
    SalesRank.sum,
    SalesRank.rank
from
    (Select
        SalesMonth.StockItemID,
        SalesMonth.month,
        SalesMonth.sum,
        rank () OVER (PARTITION BY  SalesMonth.month  ORDER BY SalesMonth.sum desc)  as rank
    from
        (SELECT
            InvoiceLines.StockItemID,
            EOMONTH (Invoices.InvoiceDate, 1) as month,
            Sum (InvoiceLines.Quantity)   as sum
        FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
            join Sales.Invoices as Invoices on
  InvoiceLines.InvoiceID = Invoices.InvoiceID
        where
   Invoices.InvoiceDate>'2015-01-01'
        Group By
   InvoiceLines.StockItemID,
  EOMONTH (Invoices.InvoiceDate, 1)) as SalesMonth) as SalesRank
where
  SalesRank.rank<=2
Order by
  month, rank
;
--4
--Функции одним запросом
--Посчитайте по таблице товаров (в вывод также должен попасть ид товара, название, брэнд и цена):
--пронумеруйте записи по названию товара, так чтобы при изменении буквы алфавита нумерация начиналась заново
--посчитайте общее количество товаров и выведете полем в этом же запросе
--посчитайте общее количество товаров в зависимости от первой буквы названия товара
--отобразите следующий id товара исходя из того, что порядок отображения товаров по имени
--предыдущий ид товара с тем же порядком отображения (по имени)
--названия товара 2 строки назад, в случае если предыдущей строки нет нужно вывести "No items"
--сформируйте 30 групп товаров по полю вес товара на 1 шт
--Для этой задачи НЕ нужно писать аналог без аналитических функций.
Select
    StockItems.StockItemID,
    StockItems.StockItemName,
    StockItems.Brand,
    StockItems.UnitPrice,
    StockItems.TypicalWeightPerUnit,
    ROW_NUMBER () OVER (PARTITION BY 1  ORDER BY StockItems.StockItemName )  as number,
    SUM(1) OVER () as count,
    SUM(1) OVER (PARTITION BY LEFT(StockItems.StockItemName, 1) ) as numberByFirstLetter,
    LEAD(StockItems.StockItemID) OVER (ORDER BY StockItems.StockItemName) as nextId,
    LAG(StockItems.StockItemID) OVER (ORDER BY StockItems.StockItemName) as id1RowsBack,
    isNULL(LAG(StockItems.StockItemName, 2) OVER (ORDER BY StockItems.StockItemName), '') as Name2RowsBack,
    NTILE(30) OVER (ORDER BY TypicalWeightPerUnit) AS weightGroup
from
    Warehouse.StockItems as StockItems
order by
StockItems.StockItemName
;

--По каждому сотруднику выведите последнего клиента, которому сотрудник что-то продал.
--В результатах должны быть ид и фамилия сотрудника, ид и название клиента, дата продажи, сумму сделки.
Select
People.PersonID as SalespersonPersonID,
    People.FullName as SalespersonPersonName,
    SalesTop.CustomerID,
    SalesTop.InvoiceDate,
    SalesTop.CustomerName,
    SalesTop.Sum
from
    Application.People as People
    left join
    (Select
        Sales.InvoiceDate,
        Sales.number,
        Sales.SalespersonPersonID,
        Sales.CustomerID,
        Sales.CustomerName,
        Sales.Sum
    FROM
        (SELECT
            Invoices.InvoiceDate as InvoiceDate,
            Quantity * UnitPrice as sum,
            Invoices.SalespersonPersonID,
            Invoices.CustomerID,
            ROW_NUMBER () OVER (PARTITION BY Invoices.SalespersonPersonID ORDER BY  Invoices.InvoiceDate DESC)  as number,
            Customers.CustomerName  as CustomerName

        FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
            join Sales.Invoices as Invoices on
			InvoiceLines.InvoiceID = Invoices.InvoiceID
            join Sales.Customers as Customers on
			Invoices.CustomerID = Customers.CustomerID
			) AS Sales
    Where 
   Sales.number<=2) as SalesTop
    on SalesTop.SalespersonPersonID = People.PersonID
where
   People.IsEmployee = 1


--Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
--В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
--Опционально можете для каждого запроса без оконных функций сделать вариант запросов с оконными функциями и сравнить их производительность.
;

   WITH customer_products AS (
SELECT
          Invoices.InvoiceDate as InvoiceDate,
          Quantity * UnitPrice as sum,
		  UnitPrice as UnitPrice,
		  Invoices.SalespersonPersonID,
		  Invoices.CustomerID,
		  InvoiceLines.StockItemID,
		  ROW_NUMBER() OVER (PARTITION BY Invoices.CustomerID ORDER BY  UnitPrice DESC)  as number,
		  Customers.CustomerName  as CustomerName
        FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
            join Sales.Invoices as Invoices on
			InvoiceLines.InvoiceID = Invoices.InvoiceID
			join Sales.Customers as Customers on
			Invoices.CustomerID = Customers.CustomerID
			)

			Select
			Customers.CustomerName,
			customer_products.InvoiceDate,
			customer_products.StockItemID,
			customer_products.UnitPrice
			from Sales.Customers as Customers
			left join customer_products as customer_products
			on customer_products.CustomerID = Customers.CustomerID
			and customer_products.number<=2