DECLARE @dml AS NVARCHAR(MAX)
DECLARE @ColumnNameSelect AS NVARCHAR(MAX)
DECLARE @ColumnNameFor AS NVARCHAR(MAX)

SELECT
    @ColumnNameSelect= ISNULL(@ColumnNameSelect + ',','') +  'IsNULL([' + Cast (Customers.CustomerID as nvarchar) + '],0) as [' + Customers.CustomerName + ']',
   -- как в предыдущем занятии  @ColumnNameSelect= ISNULL(@ColumnNameSelect + ',','') +  'IsNULL([' + Cast (Customers.CustomerID as nvarchar) + '],0) as [' + TRIM(REPLACE(REPLACE(REPLACE(Customers.CustomerName, '(',''),')',''),'Tailspin Toys','')) + ']',
    @ColumnNameFor = ISNULL(@ColumnNameFor + ',','') +  '[' + Cast (Customers.CustomerID as nvarchar) + ']'

FROM Sales.Customers as Customers

Where
  Customers.CustomerID >=1 AND Customers.CustomerID <=6

SET @dml = 'Select
    InvoiceMonth,' + @ColumnNameSelect + '
	from (SELECT
      convert(varchar,  CAST(DATEADD(mm,DATEDIFF(mm,0,InvoiceDate),0) AS DATE), 4) AS InvoiceMonth,
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
IN (' + @ColumnNameFor + ')) AS SalesResult
Order by
InvoiceMonth;'

EXEC sp_executesql @dml
