/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

SELECT
YEAR(Invoices.InvoiceDate) as YEAR,
    MOnth(Invoices.InvoiceDate) as Month,
    AVG(InvoiceLines.UnitPrice) AvgUnitPrice,
    Sum (InvoiceLines.UnitPrice*InvoiceLines.Quantity) as Sum
from Sales.Invoices as Invoices
    JOIN Sales.InvoiceLines as InvoiceLines
    on Invoices.InvoiceID = InvoiceLines.InvoiceID
GROUP BY
YEAR(Invoices.InvoiceDate), MOnth(Invoices.InvoiceDate)
Order by
YEAR, Month



/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

SELECT
YEAR(Invoices.InvoiceDate) as YEAR,
    MOnth(Invoices.InvoiceDate) as Month,
    Sum (InvoiceLines.UnitPrice*InvoiceLines.Quantity) as Sum
from Sales.Invoices as Invoices
    JOIN Sales.InvoiceLines as InvoiceLines
    on Invoices.InvoiceID = InvoiceLines.InvoiceID
GROUP BY
YEAR(Invoices.InvoiceDate), MOnth(Invoices.InvoiceDate)
HAVING
Sum (InvoiceLines.UnitPrice*InvoiceLines.Quantity)> 4600000

Order by
YEAR, Month




/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/



Select
YEAR,
Month,
StockItemID,
Max(StockItemName) as StockItemName,
Sum(Sum) as Sum,
Min(MinDate) as MinDate,
Sum(Quantity) as Quantity
from
(SELECT
YEAR(Invoices.InvoiceDate) as YEAR,
    MOnth(Invoices.InvoiceDate) as Month,
    Sum (InvoiceLines.Quantity) as Quantity,
    Sum (InvoiceLines.UnitPrice*InvoiceLines.Quantity) as Sum,
	InvoiceLines.StockItemID,
	StockItems.StockItemName as StockItemName,
	Min(Invoices.InvoiceDate) as MinDate
    
from Sales.Invoices as Invoices
    JOIN Sales.InvoiceLines as InvoiceLines
    on Invoices.InvoiceID = InvoiceLines.InvoiceID

	JOIN Warehouse.StockItems as StockItems on 
	StockItems.StockItemID = InvoiceLines.StockItemID
	
GROUP BY
YEAR(Invoices.InvoiceDate), MOnth(Invoices.InvoiceDate), 	InvoiceLines.StockItemID, StockItems.StockItemName 
HAVING
Sum (InvoiceLines.Quantity)<50) as Tab
Group By ROLLUP (YEAR, MONTH, StockItemID)

Order By
YEAR, MONTH
-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.
*/
