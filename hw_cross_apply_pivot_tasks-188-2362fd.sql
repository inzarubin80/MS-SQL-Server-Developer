/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "05 - Операторы CROSS APPLY, PIVOT, UNPIVOT".

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
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Требуется написать запрос, который в результате своего выполнения 
формирует сводку по количеству покупок в разрезе клиентов и месяцев.
В строках должны быть месяцы (дата начала месяца), в столбцах - клиенты.

Клиентов взять с ID 2-6, это все подразделение Tailspin Toys.
Имя клиента нужно поменять так чтобы осталось только уточнение.
Например, исходное значение "Tailspin Toys (Gasport, NY)" - вы выводите только "Gasport, NY".
Дата должна иметь формат dd.mm.yyyy, например, 25.12.2019.

Пример, как должны выглядеть результаты:
-------------+--------------------+--------------------+-------------+--------------+------------
InvoiceMonth | Peeples Valley, AZ | Medicine Lodge, KS | Gasport, NY | Sylvanite, MT | Jessie, ND
-------------+--------------------+--------------------+-------------+--------------+------------
01.01.2013   |      3             |        1           |      4      |      2        |     2
01.02.2013   |      7             |        3           |      4      |      2        |     1
-------------+--------------------+--------------------+-------------+--------------+------------
*/

Select
    InvoiceMonth,
    IsNULL([1],0) as [Tailspin Toys (Head Office)],
    IsNULL([2],0) as [Tailspin Toys (Sylvanite, MT)],
    IsNULL([3],0) as [Tailspin Toys (Peeples Valley, AZ)],
    IsNULL([4],0) as [Tailspin Toys (Medicine Lodge, KS)],
    IsNULL([5],0) as [Tailspin Toys (Gasport, NY)],
    IsNULL([6],0) as [Tailspin Toys (Jessie, ND)]
from (SELECT
        DATEFROMPARTS(YEAR(InvoiceDate), MONTH(InvoiceDate), 1) AS InvoiceMonth,
        Quantity * UnitPrice as sum,
        Invoices.CustomerID

    FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
        join Sales.Invoices as Invoices on
  InvoiceLines.InvoiceID = Invoices.InvoiceID
    where
  Invoices.CustomerID >=1 AND Invoices.CustomerID <=6  
  ) as SalesMonth

PIVOT(sum(SalesMonth.Sum)
FOR SalesMonth.CustomerID
IN ([1],[2],[3],[4],[5],[6])) AS SalesResult
Order by
InvoiceMonth

;

/*
2. Для всех клиентов с именем, в котором есть "Tailspin Toys"
вывести все адреса, которые есть в таблице, в одной колонке.

Пример результата:
----------------------------+--------------------
CustomerName                | AddressLine
----------------------------+--------------------
Tailspin Toys (Head Office) | Shop 38
Tailspin Toys (Head Office) | 1877 Mittal Road
Tailspin Toys (Head Office) | PO Box 8975
Tailspin Toys (Head Office) | Ribeiroville
----------------------------+--------------------
*/



SELECT
    CustomerName,
    unpvt.AddressLine
from
    (Select
        Customers.CustomerName as CustomerName,
        DeliveryAddressLine1,
        DeliveryAddressLine2,
        PostalAddressLine1,
        PostalAddressLine2
    from
        Sales.Customers as Customers
    Where
Customers.CustomerName like '%Tailspin Toys%')  p  
UNPIVOT  
   (AddressLine FOR е IN   
      (p.DeliveryAddressLine1, p.DeliveryAddressLine2, p.PostalAddressLine1, p.PostalAddressLine2)  
)AS unpvt;
;

/*
3. В таблице стран (Application.Countries) есть поля с цифровым кодом страны и с буквенным.
Сделайте выборку ИД страны, названия и ее кода так, 
чтобы в поле с кодом был либо цифровой либо буквенный код.

Пример результата:
--------------------------------
CountryId | CountryName | Code
----------+-------------+-------
1         | Afghanistan | AFG
1         | Afghanistan | 4
3         | Albania     | ALB
3         | Albania     | 8
----------+-------------+-------
*/

Select
    CountryID,
    CountryName,
    unpvt.Code
from

    (Select
        Countries.CountryID  as CountryID,
        Countries.CountryName,
        CAST(Countries.IsoNumericCode AS nvarchar(3)) as IsoNumericCode,
        IsoAlpha3Code  as IsoAlpha3Code
    from
        Application.Countries as Countries) p

UNPIVOT  
   (Code FOR е IN   
      (p.IsoNumericCode, p.IsoAlpha3Code)  
)AS unpvt

Order by
CountryID, unpvt.Code
;

/*
4. Выберите по каждому клиенту два самых дорогих товара, которые он покупал.
В результатах должно быть ид клиета, его название, ид товара, цена, дата покупки.
*/

Select
    Customers.CustomerID,
    Customers.CustomerName,
    ap.InvoiceDate,
    ap.UnitPrice,
    ap.StockItemID
from Sales.Customers as Customers
cross apply ( 
SELECT Top 2
        InvoiceDate AS InvoiceDate,
        UnitPrice as UnitPrice,
        Invoices.CustomerID,
        InvoiceLines.StockItemID
    FROM [WideWorldImporters].[Sales].[InvoiceLines] as InvoiceLines
        join Sales.Invoices as Invoices on
  InvoiceLines.InvoiceID = Invoices.InvoiceID

    where Invoices.CustomerID = Customers.CustomerID
    order by UnitPrice desc ) ap

