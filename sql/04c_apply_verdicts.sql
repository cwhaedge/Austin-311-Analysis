/* ============================================================
   04c - Apply comparability verdicts

   Run AFTER 04b. Records the outcome of the test in the mapping
   table so the methodology page can show it, and applies the
   four splits the test justified.

   Every UPDATE here is a judgment call with its evidence in the
   note. That is the point: an interviewer can read the table
   and see why each merge stands.
   ============================================================ */
USE Austin311;
GO

/* ============================================================
   SPLITS -- the test showed different work under one name
   ============================================================ */

-- Development Services runs its own, much slower code-officer queue.
-- 2023: DSD median 147 days vs 4.0 for ACD (ratio 37). Not a rename.
UPDATE dw.sr_type_mapping
SET canonical_service = 'Development Services - Code Officer Request',
    mapping_basis     = 'SPLIT_BY_TEST',
    review_note       = '04b: 2023 median 147.2 days (n=2,291) vs 3.96 for ACD (n=14,399), ratio 37. Different queue -- development cases, not code enforcement. Split from Code Officer Request.'
WHERE sr_type_desc = 'DSD - Request Code Officer';

-- Same department, same pattern for short-term rentals.
UPDATE dw.sr_type_mapping
SET canonical_service = 'Development Services - Short Term Rental Complaint',
    mapping_basis     = 'SPLIT_BY_TEST',
    review_note       = '04b: 2023 median 93.3 days (n=112) vs 1.38 for ACD (n=1,145), ratio 68. Split from Short Term Rental Complaint.'
WHERE sr_type_desc = 'DSD - Short Term Rental Complaint';

-- Water Conservation Violation is enforcement casework, open for years.
-- 2019: 1,040 days vs 3.0 for Water Waste Report. Every year agrees.
UPDATE dw.sr_type_mapping
SET canonical_service = 'Water Conservation Violation',
    mapping_basis     = 'SPLIT_BY_TEST',
    review_note       = '04b: medians of 614-1,040 days in 2019-2020 vs 2-6 days for Water Waste Report; 16.9 vs 0.9 in 2021. Enforcement casework, not a resident report. Split.'
WHERE sr_type_desc = 'AW - Water Conservation Violation';

-- Found Animal: "Pick Up" dispatches an officer; "Report - Keep" is the
-- finder keeping the animal. 0.9 vs 0.15 days, consistent over 8 years.
UPDATE dw.sr_type_mapping
SET canonical_service = 'Found Animal - Pickup',
    mapping_basis     = 'SPLIT_BY_TEST',
    review_note       = '04b: Pick Up median 0.7-2.2 days vs Report-Keep 0.13-0.83 across 2014-2022 (ratio 3-8 most years). Officer dispatch vs report-only. Split.'
WHERE sr_type_desc IN ('Found Animal - Pick Up', 'Animal Protection - Found Animal Assistance');

UPDATE dw.sr_type_mapping
SET canonical_service = 'Found Animal - Report',
    mapping_basis     = 'SPLIT_BY_TEST',
    review_note       = '04b: Report-Keep and PRC Found Pet Report agree (1.13 vs 1.04 days in 2022, ratio 1.09). Report-only service. Split from Pickup.'
WHERE sr_type_desc IN ('Found Animal Report - Keep', 'Pet Resource Center - Found Pet Report', 'ZZ - Pet Resource Center - Found Pet Report');

/* ============================================================
   KEEPS with a note -- the ones that looked wrong at first
   ============================================================ */

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: 2023 decisive year (n=2,090 vs 4,333) ratio 1.00. The 2022 anomaly (AP label median 1,038 days, n=731) is a bulk closure of stale rows, not a service difference. Merge kept.')
WHERE canonical_service = 'Injured or Sick Animal';

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: 2022 decisive year ratio 2.05 (9.9 vs 4.8 days). Earlier years show the new label running 100-700 days in its launch year -- transferred backlog, a pattern seen at every cutover. Merge kept; launch-year artefact noted.')
WHERE canonical_service = 'Graffiti Abatement - Public';

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: 2016-2017 all labels agree at ~185 days (ratio 1.01-1.08) -- a genuine two-year backlog, and strong evidence they are one queue. 2014 Emergency vs Maintenance variants differ (2.5 vs 6.8) but converge by 2015. Merge kept.')
WHERE canonical_service = 'Tree Issue - Right of Way';

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: AW - Water Waste Report agrees with the legacy label once volume is real (2019: 6.2 vs 3.0; 2020-21: ~1-2 days). 2017-18 AW medians of 500-870 days are n<200 stale batches. The Conservation Violation label was split out separately. Merge kept.')
WHERE canonical_service = 'Water Waste Report';

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: 2014 Code Compliance vs Austin Code ratio 1.04 -- clean rename. ACD 2023 3.96 days. The 2023 Austin Code median of 0.00 is a migration bulk-close of the retiring label. DSD split out separately. Merge kept.')
WHERE canonical_service = 'Code Officer Request';

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: TPW-era label slower than ATD-era in 2024 (ratio 1.5-4). Same service; the difference is the post-merger slowdown the analysis measures, not a labelling difference. Merge kept.')
WHERE canonical_service IN ('Road Markings - Maintenance', 'Road Markings - New', 'Traffic Sign New', 'Speed Management', 'Traffic Signal - New', 'Traffic Signal - Modification', 'Street Resurfacing', 'Street and Bridge Miscellaneous', 'Obstruction in Right of Way');

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: both medians under one day in every overlap year; ratio is noise at that scale. Merge kept.')
WHERE canonical_service IN ('Traffic Signal Maintenance', 'Shared Micromobility', 'Loose Animal (Not Dog)', 'Dig Tess Request', 'Wildlife Exposure', 'Animal Assistance Request');

UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: single overlap year is the cutover year with the retiring label at low n; difference is within a few days. Merge kept.')
WHERE canonical_service IN ('Animal Bite', 'Traffic Sign Maintenance', 'Flooding - Current', 'Creek and Drainage Issues', 'Telecom/Gas Utility Complaint', 'Short Term Rental Complaint');

/* Everything else that tested KEEP outright */
UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_VERIFIED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: medians agree in overlap years (ratio <= 1.5). Merge kept.')
WHERE mapping_basis = 'CONCURRENT'
  AND canonical_service IN (
    'Standing Water','Debris in Street','Parking Sign Maintenance','Dangerous Dog Investigation',
    'Alley and Unpaved Street Maintenance','Pavement Failure','Pothole Repair','Street Light Issue',
    'Animal Proper Care','Loose Dog','Lost Item in Storm Drain','Pet Resource Assistance','Sidewalk Repair',
    'Coronavirus Complaint');

/* Concurrent on paper, but no year with >=100 closed on both sides:
   the overlap is a handful of retroactively relabelled rows. */
UPDATE dw.sr_type_mapping
SET mapping_basis = 'CONCURRENT_UNTESTED',
    review_note   = CONCAT(ISNULL(review_note, ''), ' 04b: no overlap year with >=100 closed on both labels; overlap is retroactive relabelling of a few rows, not a parallel queue. Merge kept.')
WHERE mapping_basis = 'CONCURRENT';

/* Clean the boilerplate warning now that the test has run */
UPDATE dw.sr_type_mapping
SET review_note = LTRIM(REPLACE(review_note, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.', ''))
WHERE review_note LIKE '%Run the comparability test%';
GO

/* ---- Confirm: nothing left untested, new services present ---- */
SELECT mapping_basis, COUNT(*) AS labels FROM dw.sr_type_mapping GROUP BY mapping_basis ORDER BY labels DESC;

SELECT canonical_service, COUNT(*) AS labels
FROM dw.sr_type_mapping
WHERE canonical_service IN ('Development Services - Code Officer Request','Development Services - Short Term Rental Complaint',
                            'Water Conservation Violation','Found Animal - Pickup','Found Animal - Report')
GROUP BY canonical_service;
GO
