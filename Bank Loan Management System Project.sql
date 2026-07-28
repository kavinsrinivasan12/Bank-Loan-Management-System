
-- Project: bs-sql-502218 | Dataset: kavin

-- 1. Which branch has the highest total loan disbursement amount, and what is the average loan size there?

With branch_wise_loan_amnt as (
Select b.branch_id, Sum(l.principal_amount) as Loan_amnt,
Avg(l.principal_amount) as Avg_loan_amnt
From bs-sql-502218.kavin.branches_blms as b
Inner Join bs-sql-502218.kavin.loans_blms as l
On b.branch_id = l.branch_id
Group by b.branch_id),


highest_loan_amnt as (
Select *,
Dense_Rank() Over(Order by loan_amnt Desc) as drnk
From branch_wise_loan_amnt)

Select * Except(drnk)
From highest_loan_amnt
Where drnk = 1;

-- 2. What percentage of loans are currently in default status, broken down by loan type?

Select loan_type, 
Round((Countif(status = 'Defaulted') / count(loan_type) ) * 100,2) as Percentage
From bs-sql-502218.kavin.loans_blms
Group by loan_type ;

-- 3. Calculate total interest collected vs principal collected per loan type.

Select l.loan_type, Sum(lp.principal_component) as Principal_collected,
Sum(lp.interest_component) as Interest_collected
From bs-sql-502218.kavin.loans_blms as l
Inner Join bs-sql-502218.kavin.loanpayments_blms as lp
On l.loan_id = lp.loan_id
Group by l.loan_type ;

-- 4. Segment customers into credit score bands and find the loan approval rate per band.

Select Case 
When credit_score Between 300 and 549 Then 'Poor' 
When credit_score Between 550 and 649 Then 'Fair'
When credit_score Between 650 and 749 Then  'Good'
When credit_score Between 750 and 900 Then 'Excellent'
End as Credit_band,
Round((Countif(l.status != 'Pending Approval') / Count(l.loan_id) )* 100 , 2) as Loan_Approval_Rate
From bs-sql-502218.kavin.customers_blms as c 
Inner Join bs-sql-502218.kavin.loans_blms as l
on c.customer_id = l.customer_id
Group by Credit_band;

-- 5. Which branch has the highest ratio of late payments to on-time payments?

With payment_ratio as (
Select l.branch_id,
Round((Countif(lp.payment_status = "Late") /
Countif(lp.payment_status = "On-Time")), 2) Ratio
From bs-sql-502218.kavin.loans_blms as l
Inner Join bs-sql-502218.kavin.loanpayments_blms as lp
On l.loan_id = lp.loan_id
Group by l.branch_id ),

ratio_rnk as (
Select *,
Dense_Rank() Over(Order by ratio Desc) as drnk
From payment_ratio)

Select * Except(drnk)
From ratio_rnk
Where drnk = 1 ;

-- 6. What is the average time (in days) between loan disbursement and first EMI payment?

With first_emi_payment as (
Select *,
Dense_Rank() Over(Partition by l.loan_id Order by lp.payment_date) as drnk
From bs-sql-502218.kavin.loans_blms as l
Inner Join bs-sql-502218.kavin.loanpayments_blms as lp
On l.loan_id = lp.loan_id ),

filtered_first_emi_date as (
Select *
From first_emi_payment
Where drnk = 1 )

Select Avg(date_diff(payment_date , start_date, day)) as Avg_days
From filtered_first_emi_date ;

-- 7. Find customers who have taken more than one loan - flag as potentially over-leveraged.

With over_leveraged_customers as (
Select c.customer_id,
c.name, Count(l.loan_id) as Loan_cnt,
Case When Count(l.loan_id) > 1 
Then "Yes"
Else "No"
End as Potentially_Over_Leveraged
From bs-sql-502218.kavin.customers_blms as c
Inner Join bs-sql-502218.kavin.loans_blms as l 
On c.customer_id = l.customer_id
Group by c.customer_id, c.name)

Select *
From over_leveraged_customers
Where Potentially_Over_Leveraged = "Yes" ;

-- 8. Identify customers with credit cards who have missed payments (late_fee > 0) more than twice.

Select l.customer_id, c.card_type,
Countif(c.card_type like "%Credit%" and lp.late_fee > 0 ) as late_fee_cnt
From bs-sql-502218.kavin.loanpayments_blms as lp
Inner Join bs-sql-502218.kavin.loans_blms as l 
On lp.loan_id = l.loan_id
Inner Join bs-sql-502218.kavin.cards_blms as c 
On l.customer_id = c.customer_id
Group by l.customer_id, c.card_type
Having late_fee_cnt > 2 ;

-- 9. Which employees manage branches with the fastest-growing deposit base?

With branch_deposit_total as (
Select b.branch_id, e.employee_id,
Extract(year from t.txn_date) as Yr,
Extract(month from t.txn_date) as Mn,
Sum(t.amount) as Deposit_total
From bs-sql-502218.kavin.transactions_blms as t
Inner Join bs-sql-502218.kavin.accounts_blms as a
On t.account_id = a.account_id 
Inner Join bs-sql-502218.kavin.branches_blms as b
On a.branch_id = b.branch_id
Inner Join bs-sql-502218.kavin.employees_blms as e
On b.manager_id = e.employee_id  
Where t.txn_type = 'Deposit'
Group by b.branch_id, e.employee_id, Yr, Mn ),

previous_mn_deposit as (
Select *,
Lag(Deposit_total) Over(Partition by branch_id Order by Yr, Mn) as Previous_mn_deposit_amnt
From branch_deposit_total ),

growth as (
Select *,
Round((Deposit_total - Previous_mn_deposit_amnt )/ Previous_mn_deposit_amnt * 100,2)   as Growth_percent
From previous_mn_deposit ),

growing_deposit as (
Select branch_id , employee_id,
Round(Avg(growth_percent),2) as Avg_Growth_percent
From growth
Group by branch_id, employee_id ),

fastest_growing_deposit as (
Select *,
Dense_Rank() Over(Order by Avg_growth_percent Desc) as drnk
From growing_deposit )

Select * Except(drnk)
From fastest_growing_deposit
Where drnk = 1;

-- 10. Find accounts with no transactions in the last 90 days (dormant account detection).

With latest_transaction as (
Select a.account_id, t.txn_date,
Row_Number() Over(Partition by a.account_id Order by t.txn_date Desc) as rn
From bs-sql-502218.kavin.accounts_blms as a
Left Join bs-sql-502218.kavin.transactions_blms as t
On a.account_id = t.account_id ),

dormant_acnt as(
Select *, Date_diff((Select Max(txn_date) From bs-sql-502218.kavin.transactions_blms), txn_date , Day) as datediff
From latest_transaction
Where rn = 1 )

Select *
From dormant_acnt
Where datediff > 90 or txn_date is null;

-- 11. Rank employees within each branch by number of loans they have processed.

With loans_count as (
Select e.employee_id, e.branch_id,
Count(l.loan_id) as loan_cnt
From bs-sql-502218.kavin.employees_blms as e
Left Join bs-sql-502218.kavin.loans_blms as l
on e.employee_id = l.processed_by_employee_id 
Group by e.employee_id, e.branch_id )

Select *,
Dense_Rank() Over(Partition by branch_id Order by loan_cnt Desc) as drnk
From loans_count 
Order by branch_id, drnk;

-- 12. Calculate a rolling 3-month average of transaction volume per account.

With acnt_transaction_cnt as (
Select a.account_id, Extract(Year from t.txn_date) as Yr,
Extract(Month from t.txn_date) as Mn,
Count(t.transaction_id) as transaction_cnt
From bs-sql-502218.kavin.accounts_blms as a
Inner Join bs-sql-502218.kavin.transactions_blms as t  
On a.account_id = t.account_id 
Group by a.account_id, Yr, Mn ),

rolling_avg as (
Select *,
Avg(transaction_cnt) Over(Partition by account_id Order by Yr, Mn
                          Rows Between 2 Preceding And Current Row) as rolling_3mn_avg
From acnt_transaction_cnt )

Select *
From rolling_avg
Order by account_id, Yr, Mn ;

-- 13. Using LAG, calculate the change in account balance between consecutive transactions per account.

Select account_id,  txn_date, 
transaction_id, balance_after,
(balance_after -  Lag(balance_after) Over(Partition by account_id Order by txn_date, transaction_id) ) as change_in_balance
From bs-sql-502218.kavin.transactions_blms
Order by account_id,txn_date, transaction_id ;

