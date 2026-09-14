# Austin 311 Service Degradation Analysis

**Author:** Charles Haedge

## Project Overview
This project analyzes 2.5 million Austin 311 service requests spanning from 2014 to 2026 to identify which municipal services are experiencing the most severe operational degradation[cite: 4]. By tracking "excess resident-days" against historical baselines, this dashboard highlights critical bottlenecks in civic infrastructure and visualizes the impact of systemic shocks on resolution times[cite: 4].

![Dashboard Overview](images/TheFindings.png) 

## Key Findings
* **The Largest Departmental Bottleneck:** Animal services are the largest single source of excess wait (56.3K resident-days), driven by the 2024 Animal Center capacity crisis[cite: 4]. 
* **The Slowest Individual Service:** "Traffic Sign New" is the single most degraded specific service, currently running 13 days slower than its historical baseline[cite: 4].
* **Secondary Delays:** Parks maintenance is the second largest source of excess wait (49.4K resident-days), spread across four sub-services running 3 to 12 times slower than their norm[cite: 4].
* **Systemic Shocks:** The analysis tracks exact operational disruptions, such as the February 2023 Ice Storm and the October 2024 Transportation and Public Works (TPW) merger[cite: 4].

![Service Breakdown](images/Trends.png) 

## The Data Engineering Challenge
Municipal open data is notoriously inconsistent. Before analyzing the data, a robust pipeline was built to handle severe data anomalies:

* **Canonical Standardization:** Consolidated 403 messy, legacy departmental labels into 188 standardized, trackable canonical services[cite: 4].
* **Algorithmic Glitch Filtering:** Dynamically excluded a massive cohort of "ghost" tickets that were artificially skewed by a 180-day auto-close software rule in legacy Public Works and Watershed systems (2016-2021)[cite: 4]. This ensures the medians reflect genuine human wait times.
* **Target Reverse-Engineering:** Since the city does not publish target completion times, due dates were reverse-engineered based on the modal gap between creation and due dates per service[cite: 4]. 

![Data Methodology](images/Methodology.png)

## Tools & Technologies
* **Power BI:** Data visualization, DAX measure creation, conditional formatting, and dashboard design.
* **Data Source:** [Austin Texas Open Data Portal](https://data.austintexas.gov/)[cite: 4].

## How to Interact with this Project
1. View the complete static report in the `austin311.pdf` file.
2. Download the `austin311.pbix` file to explore the interactive Power BI dashboard, inspect the data model, and review the DAX measures.