# Bank Loan Management System

An end-to-end SQL analytics project on a synthetic banking dataset, built to
practice and showcase BigQuery SQL skills relevant to Data Analyst, BI Developer,
and SQL Developer roles in BFSI.

## Overview

This project simulates a bank's core operations across 8 relational tables —
customers, branches, employees, accounts, cards, loans, loan payments, and
transactions — with realistic referential integrity and intentional data-quality
issues (nulls, duplicates, orphaned edge cases) to practice real-world data
cleaning alongside analysis.

## Dataset

| Table | Rows | Description |
|---|---|---|
| customers | 8,040 | Customer demographics, credit score, occupation |
| branches | 60 | Branch details, assigned manager |
| employees | 350 | Staff records with branch and reporting hierarchy |
| accounts | 11,000 | Savings/Current/FD/NRI accounts per customer |
| cards | 4,500 | Debit and credit cards linked to accounts |
| loans | 3,000 | Loan details across 6 loan types and 4 statuses |
| loan_payments | 128,176 | EMI-level payment history with principal/interest split |
| transactions | 150,000 | Account-level transaction log |

**~305,000 total rows** across all tables, with verified zero orphaned foreign keys.

## Tech Stack

- **SQL Engine:** Google BigQuery (GoogleSQL)
- **Techniques used:** CTEs, window functions (`RANK`, `DENSE_RANK`, `ROW_NUMBER`,
  `LAG`), rolling and running aggregations, conditional aggregation (`COUNTIF`),
  multi-table joins, NULL handling, and data-quality validation

## Business Questions Solved

1. Branch with the highest total loan disbursement and average loan size
2. Default/NPA rate by loan type
3. Interest vs principal collected by loan type
4. Loan approval rate by credit score band
5. Branch with the highest late-to-on-time payment ratio
6. Average days between loan disbursement and first EMI payment
7. Customers with more than one loan (over-leverage flag)
8. Credit card holders with repeated late payments
9. Employees managing the fastest-growing deposit base (month-over-month)
10. Dormant account detection (no activity in 90+ days, including never-active accounts)
11. Ranking employees within each branch by loans processed
12. Rolling 3-month average of transaction volume per account
13. Change in account balance between consecutive transactions (`LAG`)


## Key Data-Quality Decisions

- **Dormant accounts (Q10):** used `LEFT JOIN` + `ROW_NUMBER()` (not `DENSE_RANK`)
  to guarantee one row per account, and explicitly included accounts with zero
  transactions ever — a simple `datediff > 90` filter would silently drop these,
  since SQL treats `NULL > 90` as unknown rather than true.
- **Growth rate (Q9):** used `AVG()` instead of `SUM()` when comparing branches
  with different numbers of active months, to avoid rewarding branches simply
  for having more data points.
- **Employee-loan attribution (Q11):** the base dataset had no per-loan employee
  reference, so a `processed_by_employee_id` column was added to `loans`,
  constrained to employees at the correct branch, with a few intentional NULLs
  to simulate legacy records.
- **Approval rate (Q4):** since the dataset has no explicit "Approved" status,
  approval was defined as any loan that progressed past `Pending Approval`.

