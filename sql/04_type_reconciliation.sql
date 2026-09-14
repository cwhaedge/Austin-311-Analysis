/* ============================================================
   04 - Service type reconciliation  (FULL -- all 403 raw labels)

   Generated from the actual label lifespans in dw.sr (profiling
   query 6), then reviewed by hand. Coverage is 100% of rows by
   construction; the judgment lives in canonical_service,
   mapping_basis, and in_trend.

   HOW THE LABELS BROKE -- four dated cutovers, visible in the
   first_seen / last_seen columns:
     2021-10-25  ARR retires its old labels (all "ZZZ ARR ..." die
                 that day) and rebuilds its category scheme through
                 mid-2022. Pre/post categories are NOT equivalent.
     mid-2022    "ATD - " prefixes appear on transportation labels;
                 unprefixed originals end within days.
     2023-06-01  ..06-04: a wall of legacy Public Works labels ends
                 (Pothole, Sidewalk, Debris in Street, Pavement
                 Failure, Tree Issue ROW). CRM migration, four
                 months after the ice storm.
     2024-10-11  ATD + SBO + PWD -> TPW. Every "ATD - "/"SBO - "/
                 "PWD - " label ends 10/07-10/13; its "TPW - " twin
                 starts 10/08-10/14.

   mapping_basis values:
     CONFIRMED_RENAME  live labels for this service have disjoint
                       date ranges (<=21 days overlap). Safe merge.
     CONCURRENT        two or more live labels overlap in time.
                       Either (a) the CRM relabelled some historical
                       rows in place -- e.g. "TPW - Traffic Sign
                       Maintenance" has first_seen 2014, a decade
                       before TPW existed -- or (b) two departments
                       ran parallel queues (all the "Animal
                       Protection - X" pairs, 2014-2023). Merge is
                       only safe if the labels behave alike: run
                       04b_comparability_test.sql and keep the
                       merges whose medians agree.
     RESTRUCTURED      ARR category rebuild; old and new definitions
                       differ. in_trend = 0 for the 2015-2019
                       baseline; analyse with a 2022+ baseline.
     RETIRED_ALIAS     "ZZ"/"ZZZ"/"Zz_" prefix = retired in the CRM.
                       Rows keep the label; map to the live service.
     SINGLETON         one live label.
     EXCLUDED_TEST     CRM configuration test records. Drop.

   in_trend = 0 for: event-driven services (storm debris, COVID,
   heat advisory, fireworks), informational/internal workflow
   types (Follow-Up, Callback, Contact Request, Other, feedback),
   test records, and RESTRUCTURED ARR categories.
   ============================================================ */
USE Austin311;
GO

DROP TABLE IF EXISTS dw.sr_type_mapping;
CREATE TABLE dw.sr_type_mapping (
    sr_type_desc      NVARCHAR(200) NOT NULL PRIMARY KEY,
    canonical_service NVARCHAR(200) NOT NULL,
    service_group     NVARCHAR(100) NOT NULL,
    mapping_basis     NVARCHAR(30)  NOT NULL,
    is_event_driven   BIT           NOT NULL DEFAULT 0,
    in_trend          BIT           NOT NULL DEFAULT 1,
    review_note       NVARCHAR(600) NULL
);
GO

INSERT INTO dw.sr_type_mapping
    (sr_type_desc, canonical_service, service_group, mapping_basis, is_event_driven, in_trend, review_note)
VALUES
('Austin Code - Request Code Officer', 'Code Officer Request', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=213,556
('Traffic Signal - Maintenance', 'Traffic Signal Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=98,659
('ARR - Garbage', 'Garbage Collection', 'Solid Waste', 'SINGLETON', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=97,740
('Loose Dog', 'Loose Dog', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=79,945
('APD - Non Emergency Noise/Alarm', 'Non-Emergency Noise or Alarm', 'Public Safety', 'SINGLETON', 0, 1, NULL),  -- n=70,197
('DSD - Request Code Officer', 'Code Officer Request', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=64,658
('ARR - Compost', 'Compost Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=60,980
('ARR Missed Recycling', 'Recycling Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=55,380
('Animal Control - Assistance Request', 'Animal Assistance Request', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=54,675
('Park Maintenance - Grounds', 'Park Maintenance - Grounds', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=52,121
('ARR - Recycling', 'Recycling Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=50,808
('ARR - Storm Debris Collection', 'Storm Debris Collection', 'Solid Waste', 'SINGLETON', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=49,751
('ARR Dead Animal Collection', 'Dead Animal Collection', 'Animal', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=49,048
('Injured / Sick Animal', 'Injured or Sick Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=47,027
('Street Light Issue- Address', 'Street Light Issue', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=45,956
('APD - Vehicle Abatement Report', 'Vehicle Abatement Report', 'Public Safety', 'SINGLETON', 0, 1, NULL),  -- n=42,833
('ATD - Parking Violation Enforcement', 'Parking Violation Enforcement', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=42,161
('TPW - Parking Violation Enforcement', 'Parking Violation Enforcement', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=38,995
('ARR Missed Yard Trimmings/Compost', 'Compost Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=35,657
('APD - Non Emergency Collision', 'Non Emergency Collision', 'Public Safety', 'SINGLETON', 0, 1, NULL),  -- n=32,924
('311 CC - Other', 'Uncategorised', 'Other', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=31,197
('Pothole Repair', 'Pothole Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=30,478
('Animal Protection - Loose Dog', 'Loose Dog', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=30,286
('ARR - Dead Animal Collection', 'Dead Animal Collection', 'Animal', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=27,145
('ARR - Bulk', 'Bulk Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=27,050
('ATD - Shared Micromobility', 'Shared Micromobility', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=25,935
('Animal Protection - Injured/Sick Animal', 'Injured or Sick Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=25,575
('TPW - Traffic Signal - Maintenance', 'Traffic Signal Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=24,046
('AE Street Light Issue - Address', 'Street Light Issue', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=23,485
('Tree Issue ROW', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=22,473
('Debris in Street', 'Debris in Street', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=20,875
('Loud Commercial Music', 'Loud Commercial Music', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=20,039
('DSD - Follow-Up', 'Follow-Up', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=18,199
('Code Compliance', 'Code Officer Request', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=17,849
('ARR - General', 'Solid Waste - General Request', 'Solid Waste', 'SINGLETON', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=17,108
('Animal - Proper Care', 'Animal Proper Care', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=16,252
('ARR Brush and Bulk', 'Bulk and Brush Collection (legacy)', 'Solid Waste', 'SINGLETON', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=16,053
('Water Waste Report', 'Water Waste Report', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=15,735
('Public Health - Graffiti Abatement', 'Graffiti Abatement - Public', 'Public Health', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=15,518
('Sign - Traffic Sign Maintenance', 'Traffic Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=15,109
('Traffic Signal - Dig Tess Request', 'Dig Tess Request', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=14,539
('ACD - Request Code Officer', 'Code Officer Request', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=14,453
('ARR Missed Yard Trimmings /Organics', 'Compost Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=14,299
('Parking Violation Enforcement', 'Parking Violation Enforcement', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=13,811
('Graffiti Abatement', 'Graffiti Abatement - Public', 'Public Health', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=13,573
('Austin Code - Short Term Rental Complaint SR', 'Short Term Rental Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,875
('Pet Resource Center - Assistance Request', 'Pet Resource Assistance', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,859
('Animal Bite', 'Animal Bite', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,856
('Obstruction in ROW', 'Obstruction in Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,797
('Animal Services - Contact Request', 'Contact Request', 'Animal', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=12,757
('Wildlife Exposure', 'Wildlife Exposure', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,726
('Animal Protection - Assistance Request', 'Animal Assistance Request', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,665
('Parking Machine Issue', 'Parking Machine Issue', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=12,467
('Found Animal - Pick Up', 'Found Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,306
('AW - Water Conservation Violation', 'Water Waste Report', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=12,196
('Sidewalk Repair', 'Sidewalk Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=11,990
('Sign - New', 'Traffic Sign New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=11,719
('Lane/Road Closure Notification', 'Lane/Road Closure Notification', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=11,613
('Found Animal Report - Keep', 'Found Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=11,577
('ARR - Brush', 'Brush Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=11,271
('Shared Micromobility', 'Shared Micromobility', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=11,205
('ATD - Traffic Signal - Maintenance', 'Traffic Signal Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=9,418
('DSD - Outdoor Commercial Venue Music Complaint', 'Loud Commercial Music', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=9,376
('WPD - Channels/Creek/Drainage Issues', 'Creek and Drainage Issues', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=9,098
('APH - Graffiti Abatement - Public Property', 'Graffiti Abatement - Public', 'Public Health', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=8,986
('ATD - Traffic Sign Maintenance', 'Traffic Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=8,932
('Pavement Failure', 'Pavement Failure', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=8,206
('Sign - Traffic Sign Emergency', 'Traffic Sign Emergency', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=8,145
('Loud Music', 'Loud Commercial Music', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=8,057
('Concerns in the ROW', 'Concerns in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=7,871
('Animal Protection - Animal Proper Care', 'Animal Proper Care', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=7,649
('Animal Protection - Animal Bite', 'Animal Bite', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=7,580
('TPW - Tree Issue Right of Way', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=7,293
('ATD - Lane/Road Closure Notification', 'Lane/Road Closure Notification', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=7,023
('Channels/Creeks/Drainage Easement', 'Creek and Drainage Issues', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=6,850
('Traffic Signal - New/Change', 'Traffic Signal - New or Modification (legacy)', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=6,576
('Dockless Mobility', 'Shared Micromobility', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=6,454
('ATD - Concerns in Right of Way', 'Concerns in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=6,328
('Public Health - Environmental Services - City', 'Environmental Health - City', 'Public Health', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=6,327
('Park Maintenance - Grounds Plumbing Issues', 'Park Maintenance - Grounds Plumbing Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=6,221
('TPW - Debris in Street', 'Debris in Street', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=6,055
('TPW - Pothole Repair', 'Pothole Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,881
('Austin Code - Coronavirus', 'Coronavirus Complaint', 'Code', 'CONCURRENT', 1, 0, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Event-driven volume. Excluded from degradation ranking.'),  -- n=5,810
('Construction items in ROW', 'Construction Items in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=5,807
('Tree Issue ROW/Emergency (PW)', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,675
('Animal Protection - Found Animal Assistance', 'Found Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,587
('Loose Animal Not Dog', 'Loose Animal (Not Dog)', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,504
('Austin Code - Signs/Billboards', 'Billboard Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,455
('ARR - Street Sweeping', 'Street Sweeping', 'Solid Waste', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=5,447
('ATD - Parking Sign Maintenance', 'Parking Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,439
('Dangerous/Vicious Dog Investigation', 'Dangerous Dog Investigation', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,370
('TPW - Obstruction in Right of Way', 'Obstruction in Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,334
('PWD - Tree Issue Right of Way', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5,068
('ARR Street Sweeping', 'Street Sweeping', 'Solid Waste', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=4,999
('SBO - Pothole Repair', 'Pothole Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,784
('AW - Water Waste Report', 'Water Waste Report', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,749
('APH - Environmental Health Services - City', 'Environmental Health - City', 'Public Health', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=4,695
('Road Markings/Striping - Maintenance', 'Road Markings - Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,693
('Tree Issue ROW/Maintenance (PW)', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,688
('TPW - Construction Concerns in Right of Way', 'Construction Concerns in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=4,660
('Traffic Engineering - General', 'Traffic Engineering - General', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,608
('View Obstruction at Intersection', 'View Obstruction at Intersection', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=4,522
('Sign - Street Name', 'Street Name Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,338
('Animal Protection - Wildlife Exposure', 'Wildlife Exposure', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,315
('TPW - Traffic Sign Maintenance', 'Traffic Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,286
('Creek & Pond Vegetation Control', 'Creek and Pond Vegetation', 'Watershed', 'SINGLETON', 0, 1, NULL),  -- n=4,221
('TPW - Parking Sign Maintenance', 'Parking Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,164
('Coyote Complaints', 'Coyote Complaints', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,141
('Bicycle Issues', 'Bicycle and Pedestrian Issues', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4,024
('Community Connections - Coronavirus', 'Coronavirus Complaint', 'Code', 'CONCURRENT', 1, 0, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Event-driven volume. Excluded from degradation ranking.'),  -- n=3,895
('School Zone Flasher - Timing/Maintenance', 'School Zone Beacon Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,863
('Park Maintenance - Grounds Electrical Issues', 'Park Maintenance - Grounds Electrical Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=3,766
('DSD - Environmental Complaint', 'Environmental Complaint', 'Code', 'SINGLETON', 0, 1, NULL),  -- n=3,760
('Alley & Unpaved Street Maintenance', 'Alley and Unpaved Street Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,672
('SBO - Debris in Street', 'Debris in Street', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,662
('DSD - Tree and Environmental Complaint', 'Tree and Environmental Complaint', 'Code', 'SINGLETON', 0, 1, NULL),  -- n=3,660
('DSD - Alarm Administration', 'Alarm Administration', 'Code', 'SINGLETON', 0, 1, NULL),  -- n=3,551
('TPW - Dig Tess Request', 'Dig Tess Request', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,522
('Aquatics Hotline Inquiry', 'Aquatic Inquiries', 'Parks', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=3,426
('Sign - Parking Sign Maintenance', 'Parking Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,343
('Park Maintenance - Pool Issues', 'Park Maintenance - Pool Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=3,342
('SBO - Obstruction in Right of Way', 'Obstruction in Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,331
('Animal In Vehicle', 'Animal in Vehicle', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,296
('APD - Vehicle Abatement Callback Request', 'Vehicle Abatement Callback Request', 'Public Safety', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=3,259
('Flooding  Current (Non-Emergency)', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,246
('AW - Water Related Issues', 'Water Related Issues', 'Utilities', 'SINGLETON', 0, 1, NULL),  -- n=3,192
('ATD - Construction Items in Right of Way', 'Construction Items in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=3,132
('Mowing Medians', 'Mowing Medians', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3,022
('TPW - Shared Micromobility', 'Shared Micromobility', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,992
('DSD - Short Term Rental Complaint', 'Short Term Rental Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,960
('TPW - Sidewalk Repair', 'Sidewalk Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,905
('Lost Item in Storm Drainage System', 'Lost Item in Storm Drain', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,854
('ATD - Speed Management', 'Speed Management', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,845
('Pet Resource Center - Found Pet Report', 'Found Animal', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,785
('ATD - Traffic Sign New', 'Traffic Sign New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,752
('TPW - Lane/Road Closure Notification', 'Lane/Road Closure Notification', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=2,747
('ARR - On Call Bulk', 'Bulk Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=2,686
('Traffic Calming', 'Speed Management', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,681
('TPW - Traffic Sign New', 'Traffic Sign New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,616
('Animal Protection - Vicious Dog Complaint', 'Dangerous Dog Investigation', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,602
('ZZ - AFD - Fireworks Complaint', 'Fireworks Complaint', 'Public Safety', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=2,524
('Road Markings/Striping - New', 'Road Markings - New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,521
('Park Maintenance - Building Plumbing Issues', 'Park Maintenance - Building Plumbing Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=2,506
('WPD - Storm Drain Services', 'Storm Drain Services', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,484
('ATD - Dig Tess Request', 'Dig Tess Request', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,479
('AE Street Light Issue - No Address', 'Street Light Issue', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,475
('Sidewalk/Curb Ramp/Route - NEW', 'New Sidewalk/Curb Ramp', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,364
('TPW - Road Markings/Striping - Maintenance', 'Road Markings - Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,334
('Street Light Issue- Multiple poles/multiple streets', 'Street Light Issue', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,328
('Street Lights New', 'Street Lights - New', 'Utilities', 'SINGLETON', 0, 1, NULL),  -- n=2,287
('TPW - Speed Management', 'Speed Management', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,264
('TPW - Pavement Failure', 'Pavement Failure', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,249
('ATD - Road Markings/Striping - Maintenance', 'Road Markings - Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=2,232
('TPW - Parking Machine Issue', 'Parking Machine Issue', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=2,206
('ARR - Household Hazardous Waste', 'Household Hazardous Waste', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=2,189
('AFD - Fireworks Complaint', 'Fireworks Complaint', 'Public Safety', 'SINGLETON', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=1,992
('SBO - Sidewalk Repair', 'Sidewalk Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,980
('ATD - Street Name Sign Maintenance', 'Street Name Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,965
('TPW - Traffic Signal - Modification', 'Traffic Signal - Modification', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,944
('WPD - Standing Water', 'Standing Water', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,924
('ATD - Parking Machine Issue', 'Parking Machine Issue', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=1,892
('TPW - Activate/Deactivate Work Zone', 'Work Zone Activation', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=1,888
('ATD - Construction Concerns in Right of Way', 'Construction Concerns in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=1,885
('Mowing City Parks', 'Mowing City Parks', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=1,868
('Animal Protection - Loose Animal Not Dog', 'Loose Animal (Not Dog)', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,851
('ARR - Collection Truck Spillage', 'Collection Truck Spillage', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=1,771
('Tree Issue ROW/Maintenance (PARD)', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,757
('Animal Protection - Coyote Complaints', 'Coyote Complaints', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,736
('TPW - Traffic Sign Emergency', 'Traffic Sign Emergency', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=1,734
('Flooding - Past', 'Flooding - Past', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,686
('Curb/Gutter Repair', 'Curb/Gutter Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,682
('Standing Water', 'Standing Water', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,648
('WPD - Lost Item in Storm Drainage System', 'Lost Item in Storm Drain', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,615
('ATD - Traffic Sign Emergency', 'Traffic Sign Emergency', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=1,588
('TPW - Street and Bridge Miscellaneous', 'Street and Bridge Miscellaneous', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,563
('ARR - Property Damage Report', 'Property Damage Report', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=1,560
('ARR - Special Services', 'Special Services', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=1,549
('WPD - Drainage Pond Maintenance', 'Drainage Pond Maintenance', 'Watershed', 'SINGLETON', 0, 1, NULL),  -- n=1,481
('Street Resurfacing', 'Street Resurfacing', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,464
('Park Maintenance - Building Issues', 'Park Maintenance - Building Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=1,451
('ARR - Spillage Trash/Fluids', 'Spillage Trash/Fluids', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=1,425
('Tree Issue ROW/Emergency (PARD)', 'Tree Issue - Right of Way', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,388
('ZZ AFD - Fireworks Complaint', 'Fireworks Complaint', 'Public Safety', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=1,346
('TPW - Street Resurfacing', 'Street Resurfacing', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,333
('ATD - Traffic Signal Maintenance', 'Traffic Signal Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,321
('Animal Trapped in Storm Drain', 'Animal Trapped in Storm Drain', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,244
('TPW - Street Name Sign Maintenance', 'Street Name Sign Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,234
('Speed Management', 'Speed Management', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,227
('SBO - Pavement Failure', 'Pavement Failure', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,217
('PARD - Aquatic Maintenance', 'Aquatic Maintenance', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,215
('TARA - Telecommunication Complaint', 'Telecom/Gas Utility Complaint', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,192
('ACD - Short Term Rental Complaint', 'Short Term Rental Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,188
('Pet Resource Center - Stray Assistance', 'Pet Resource Assistance', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,179
('WPD - Environmental Spills', 'Environmental Spills', 'Watershed', 'SINGLETON', 0, 1, NULL),  -- n=1,129
('WPD - Flooding Current', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,078
('Bat Complaint', 'Bat Complaint', 'Animal', 'SINGLETON', 0, 1, NULL),  -- n=1,076
('Zz_Loud Commercial Music', 'Loud Commercial Music', 'Code', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=1,069
('ATD - Road Markings/Striping - New', 'Road Markings - New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=1,064
('311 E-Comm - Other', 'Uncategorised', 'Other', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=1,034
('DSD - Case Updates/Code Connect Messages', 'Case Updates/Code Connect Messages', 'Code', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=1,018
('ATD - Booting Complaint', 'Booting Complaint', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=1,003
('TPW - View Obstruction and Fencing at Intersection', 'View Obstruction at Intersection', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=999
('Animal Protection - Animal In Vehicle', 'Animal in Vehicle', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=987
('FSD - Telecommunication/Gas Utility Complaint', 'Telecom/Gas Utility Complaint', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=987
('Construction Items- ROW', 'Construction Items in Right of Way', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=952
('TPW - Road Markings/Striping - New', 'Road Markings - New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=952
('ATD - Bicycle &amp; Pedestrian Issues', 'Bicycle and Pedestrian Issues', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=904
('TPW - Mowing Medians', 'Mowing Medians', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=889
('Austin Code - Short Term Rental (STR) Appointment', 'Short Term Rental Appointment', 'Code', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=875
('SBO - Street and Bridge Miscellaneous', 'Street and Bridge Miscellaneous', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=818
('Park Maintenance - Building A/C & Heating Issues', 'Park Maintenance - Building A/C & Heating Issues', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=816
('Animal Protection - Dog Restraint Issues', 'Dog Restraint Issues', 'Animal', 'SINGLETON', 0, 1, NULL),  -- n=805
('ATD - School Zone Beacon - Maintenance', 'School Zone Beacon Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=804
('School Zone - New/Review/Changes', 'School Zone - New or Review', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=791
('Code Compliance - Signs/Billboards', 'Billboard Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=789
('TPW - Traffic Signal - New', 'Traffic Signal - New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=781
('311 CRIS - City Vehicle Report', 'City Vehicle Report', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=777
('ATD - View Obstruction and Fencing at Intersection', 'View Obstruction at Intersection', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=774
('SBO - New Sidewalk/Curb Ramp/Route', 'New Sidewalk/Curb Ramp', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=770
('TPW - Bicycle Issues', 'Bicycle and Pedestrian Issues', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=768
('AE - Electric Vehicle Station Issues', 'EV Station Issues', 'Utilities', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=737
('Zz_ARR - Storm Debris Collection', 'Storm Debris Collection', 'Solid Waste', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=736
('Speed Limit - Changes/Signs', 'Speed Limit Changes', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=735
('TPW - Alley & Unpaved Street Maintenance', 'Alley and Unpaved Street Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=732
('ATD - Traffic Signal - Modification', 'Traffic Signal - Modification', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=727
('Flooding Current (Non-Emergency)', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=696
('ATD - Traffic Signal - New/Modification', 'Traffic Signal - New or Modification (legacy)', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=686
('PWD - Mowing Medians', 'Mowing Medians', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=685
('TPW - Curb/Gutter Repair', 'Curb/Gutter Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=674
('TPW - Utility Cut Repair', 'Utility Cut Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=658
('Ditch/Driveway Pipe Services', 'Ditch/Driveway Pipe Services', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=649
('Sign - School Zone Sign Maintenance', 'School Zone Sign Maintenance', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=647
('Guardrail New/Repair', 'Guardrail New/Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=641
('Street Resurfacing Inquiry', 'Street Resurfacing Inquiry', 'Transportation', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=610
('DSD - Graffiti Abatement - Private Property', 'Graffiti Abatement - Private', 'Code', 'SINGLETON', 0, 1, NULL),  -- n=610
('SBO - Street Resurfacing', 'Street Resurfacing', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=585
('Neighborhood Home Programs', 'Neighborhood Home Programs', 'Housing', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=569
('Animal Protection - Animal Trapped in Storm Drain', 'Animal Trapped in Storm Drain', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=556
('Pet Resource Center - Resource Assistance', 'Pet Resource Assistance', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=549
('TPW - Pedestrian Crossing New/Modify', 'Pedestrian Crossing New/Modify', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=549
('ATD - Special Event', 'Special Event', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=548
('WPD - Flooding Past', 'Flooding - Past', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=544
('TPW - Special Event', 'Special Event', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=537
('WPD - Ditch/Driveway Pipe Services', 'Ditch/Driveway Pipe Services', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=517
('AW - Water Theft Report', 'Water Theft Report', 'Utilities', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=512
('Storm Drain Pipe Services', 'Storm Drain Services', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=496
('Construction/Permitting- ROW', 'Construction/Permitting- ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=492
('TPW - New Sidewalk/Curb Ramp/ADA Route', 'New Sidewalk/Curb Ramp', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=482
('Water Theft Report', 'Water Theft Report', 'Utilities', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=481
('WPD - Watershed Grow Zone Issues', 'Watershed Grow Zone Issues', 'Utilities', 'SINGLETON', 0, 1, NULL),  -- n=473
('ARR - On Call Brush', 'Brush Collection', 'Solid Waste', 'RESTRUCTURED', 0, 0, 'ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=447
('TPW - Booting Complaint', 'Booting Complaint', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=443
('SBO - Utility Cut Repair', 'Utility Cut Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=433
('ACD - Case Updates/Code Connect Messages', 'Case Updates/Code Connect Messages', 'Code', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=432
('ATD - Traffic Signal - New', 'Traffic Signal - New', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=416
('Roadway Spillage', 'Roadway Spillage', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=409
('Parking Ticket Complaint', 'Parking Ticket Complaint', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=407
('Park Maintenance - Building Electrical Issues', 'Park Maintenance - Building Electrical Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=390
('School Issues - Crossing Guards', 'Crossing Guards', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=387
('ARR - Pet Search', 'Pet Search', 'Animal', 'SINGLETON', 0, 1, NULL),  -- n=386
('WPD - Lady Bird Lake Debris Issues', 'Lady Bird Lake Debris', 'Watershed', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=380
('Bridge Repair', 'Bridge Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=376
('SBO - Alley & Unpaved Street Maintenance', 'Alley and Unpaved Street Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=369
('Drainage - Miscellaneous', 'Creek and Drainage Issues', 'Watershed', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=366
('Loose Animal (not dog)', 'Loose Animal (Not Dog)', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=365
('ZZ - ARR - Storm Debris Collection', 'Storm Debris Collection', 'Solid Waste', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=364
('APH - Environmental Health Services - County', 'Environmental Health - County', 'Public Health', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=364
('Public Health - Environmental Services - County', 'Environmental Health - County', 'Public Health', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=364
('Guardrail Repair', 'Guardrail New/Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=357
('WPD - Erosion', 'Erosion', 'Watershed', 'SINGLETON', 0, 1, NULL),  -- n=351
('SBO - Curb/Gutter Repair', 'Curb/Gutter Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=348
('Code Compliance - Short Term Rental (STR) Appointment', 'Short Term Rental Appointment', 'Code', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=345
('Park Maintenance - Cemeteries', 'Park Maintenance - Cemeteries', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=344
('ATD - School Zone Sign Maintenance', 'School Zone Sign Maintenance', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=343
('Austin Code - Construction Rest Break Complaint', 'Construction Rest Break Complaint', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=335
('CPIO - Community Voices', 'Community Voices', 'Other', 'CONCURRENT', 0, 0, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=320
('TPW - Guardrail New/Repair', 'Guardrail New/Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=319
('AFD - Wildfire Concern / Presentation', 'Wildfire Concern / Presentation', 'Public Safety', 'SINGLETON', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=317
('PARD - Commercial Use of Parkland', 'Commercial Use of Parkland', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=302
('ZZ - Tree Issue ROW', 'Tree Issue - Right of Way', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=278
('Short Term Rental Complaint SR', 'Short Term Rental Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=278
('TPW - School Zone Beacon - Maintenance', 'School Zone Beacon Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=278
('ATD - Pay-by-Phone App', 'Pay-by-Phone App', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=273
('Animal Protection - Dangerous Dog Complaint', 'Dangerous Dog Investigation', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=265
('APH - Community Connections Coronavirus', 'Coronavirus Community Connections', 'Public Health', 'SINGLETON', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=265
('AE - Key Accounts', 'Key Accounts', 'Utilities', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=254
('Animal Roadside Sales', 'Animal Roadside Sales', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=250
('DSD - Billboard Complaint', 'Billboard Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=245
('APR (PARD) - Aquatic Maintenance', 'Aquatic Maintenance', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=233
('Barricade Request', 'Barricade Request', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=228
('TPW - Pay-by-Phone App', 'Pay-by-Phone App', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=227
('HD - Neighborhood Home Programs', 'Neighborhood Home Programs', 'Housing', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=219
('SBO - Alley &amp; Unpaved Street Maintenance', 'Alley and Unpaved Street Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=214
('SBO - Guardrail New/Repair', 'Guardrail New/Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=214
('TPW - Roadway Spillage', 'Roadway Spillage', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=212
('AFS - Telecommunication/Gas Utility Complaint', 'Telecom/Gas Utility Complaint', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=211
('Corridor Program Office - Corridor Feedback', 'Corridor Feedback', 'Transportation', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=188
('TPW - School Zone Sign Maintenance', 'School Zone Sign Maintenance', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=180
('TPW - Bridge Repair', 'Bridge Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=178
('AFD - Wildfire Education', 'Wildfire Education', 'Public Safety', 'SINGLETON', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=178
('Residential Parking Permit Enforcement', 'Residential Parking Permit Enforcement', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=177
('HPD - Neighborhood Home Programs', 'Neighborhood Home Programs', 'Housing', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=176
('PW - School Issues - Crossing Guards', 'Crossing Guards', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=145
('Flood Report', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=143
('Basic Needs - Appointment', 'Basic Needs - Appointment', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=139
('PARD - Aquatic Program Inquiries', 'Aquatic Inquiries', 'Parks', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=138
('ZZ - Pet Resource Center - Assistance Request', 'Pet Resource Assistance', 'Animal', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=136
('Animal Protection - Animal Roadside Sales', 'Animal Roadside Sales', 'Animal', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=136
('Vendor Permit - ROW', 'Vendor Permit - ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=136
('TPW - Alley &amp; Unpaved Street Maintenance', 'Alley and Unpaved Street Maintenance', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=130
('Ordinance Universal Recycling', 'Ordinance Universal Recycling', 'Solid Waste', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=129
('Austin Code - Construction Ordinance SR', 'Construction Ordinance Complaint', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=125
('PARD - Aquatic Inquiries/Issues', 'Aquatic Inquiries', 'Parks', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=124
('TPW - School Issues - Crossing Guards', 'Crossing Guards', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=124
('Parking Permit- ROW', 'Parking Permit- ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=115
('TPW - New Sidewalk/Curb Ramp/Route', 'New Sidewalk/Curb Ramp', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=106
('SBO - Roadway Spillage', 'Roadway Spillage', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=102
('ZZ - Pet Resource Center - Found Pet Report', 'Found Animal', 'Animal', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=99
('PW - School Zone - New/Review/Changes', 'School Zone - New or Review', 'Transportation', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=99
('Flooding - Storms After Business Hours', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=97
('EV PIE Station Issues', 'EV Station Issues', 'Utilities', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=96
('ZZ Park Maintenance - Pool Issues', 'Park Maintenance - Pool Issues', 'Parks', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=95
('Town Lake Debris Issues', 'Lady Bird Lake Debris', 'Watershed', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=93
('Park Maintenance - Building Electric Issues', 'Park Maintenance - Building Electric Issues', 'Parks', 'SINGLETON', 0, 1, NULL),  -- n=93
('APH - Health Equity Line', 'Health Equity Line', 'Public Health', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=89
('Zz_Traffic Engineering - General', 'Traffic Engineering - General', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=82
('ACD - Billboard Complaint', 'Billboard Complaint', 'Code', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=80
('SBO - Bridge Repair', 'Bridge Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=78
('Ordinance Single-Use Carryout Bags', 'Ordinance Single-Use Carryout Bags', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=77
('Dangerous Animal - Except Dogs', 'Dangerous Animal - Except Dogs', 'Animal', 'SINGLETON', 0, 1, NULL),  -- n=73
('Emergency Road Closure Report', 'Emergency Road Closure Report', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=69
('TPW - Bicycle and Pedestrian Issues', 'Bicycle and Pedestrian Issues', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=64
('Fence/Wall Repair', 'Fence/Wall Repair', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=60
('ERM - Harmful Algae', 'Harmful Algae', 'Watershed', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=60
('Road Sanding Request', 'Road Sanding Request', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=59
('ZZ Creek &amp; Pond Vegetation Control', 'Creek and Pond Vegetation', 'Watershed', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=57
('ZZZ ARR Brush and Bulk', 'Bulk and Brush Collection (legacy)', 'Solid Waste', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=53
('ZZZ ARR Missed Recycling', 'Recycling Collection', 'Solid Waste', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=51
('ARR Dumpster', 'Dumpster', 'Solid Waste', 'SINGLETON', 0, 1, NULL),  -- n=51
('ACE - Community Voices', 'Community Voices', 'Other', 'CONCURRENT', 0, 0, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=50
('APR (PARD) - Commercial Use of Parkland', 'Commercial Use of Parkland', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=50
('Construction Ordinance SR', 'Construction Ordinance Complaint', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=46
('APD - Non Emergency Hands Free Violation', 'Non Emergency Hands Free Violation', 'Public Safety', 'SINGLETON', 0, 1, NULL),  -- n=45
('Park Maintenance - Building A/C &amp; Heating Issues', 'Park Maintenance - Building A/C & Heating Issues', 'Parks', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=43
('Obstruction - Urban Forestry', 'Obstruction - Urban Forestry', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=42
('ZZ ARR - On Call Brush', 'Brush Collection', 'Solid Waste', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=41
('ATD - Bicycle & Pedestrian Issues', 'Bicycle and Pedestrian Issues', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=41
('ZZZ ARR Missed Yard Trimmings/Compost', 'Compost Collection', 'Solid Waste', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=39
('Filming Permit - ROW', 'Filming Permit - ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=39
('CPIO - Community Engagement Project Feedback', 'Community Engagement Project Feedback', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=38
('ACD - Construction Rest Break Complaint', 'Construction Rest Break Complaint', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=36
('EV PIP Residential Rebate', 'EV PIP Residential Rebate', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=36
('ZZZ ARR Dead Animal Collection', 'Dead Animal Collection', 'Animal', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=34
('Valet Permit - ROW', 'Valet Permit - ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=32
('ZZ Mowing City Parks', 'Mowing City Parks', 'Parks', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=31
('DSD - Private Hauler License Violation', 'Private Hauler License Violation', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=30
('Newspaper Rack- ROW', 'Newspaper Rack- ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=30
('ZZ ARR - On Call Bulk', 'Bulk Collection', 'Solid Waste', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. ARR rebuilt its category scheme Oct 2021-Jun 2022; pre/post definitions differ. Excluded from the 2015-2019 baseline comparison; analyse with a 2022+ baseline.'),  -- n=27
('Guardrail - New', 'Guardrail New/Repair', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=27
('ZZ Creek & Pond Vegetation Control', 'Creek and Pond Vegetation', 'Watershed', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=26
('HSEM - Heat Advisory', 'Heat Advisory', 'Other', 'CONFIRMED_RENAME', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=26
('APR (PARD) - Aquatic Program Inquiries', 'Aquatic Inquiries', 'Parks', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=24
('WPD - Harmful Algae', 'Harmful Algae', 'Watershed', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=24
('LeadSmart Program', 'LeadSmart Program', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=24
('AH (HD) - Neighborhood Home Programs', 'Neighborhood Home Programs', 'Housing', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=22
('ZZ ARR - Storm Debris Collection', 'Storm Debris Collection', 'Solid Waste', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=20
('Flooding - Storms During Business Hours', 'Flooding - Current', 'Public Safety', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=16
('ZZ DSD - Graffiti Abatement - Private Property', 'Graffiti Abatement - Private', 'Code', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=16
('Corridor Program - Corridor Feedback', 'Corridor Feedback', 'Transportation', 'CONFIRMED_RENAME', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=16
('ZZ CRM - Configuration Test Waheed', 'CRM - Configuration Test Waheed', 'Test', 'EXCLUDED_TEST', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=16
('ZZ Mowing Medians', 'Mowing Medians', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=15
('ZZ ATD - Parking Machine Issue', 'Parking Machine Issue', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=14
('Zz_ATD - Concerns in Right of Way', 'Concerns in Right of Way', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=14
('DSD - Construction Rest Break Complaint', 'Construction Rest Break Complaint', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=14
('Traffic Engineering - Jurisdiction Issue', 'Jurisdiction Issue', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=11
('zzDSD - Alarm Administration', 'Alarm Administration', 'Code', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=10
('Fence Repair - MOPAC', 'Fence Repair - MOPAC', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=10
('zz - Coyote Compliants', 'Coyote Complaints', 'Animal', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=7
('ZZ_TPW - Pedestrian Crossing New/Modify', 'Pedestrian Crossing New/Modify', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=7
('Basic Needs - Information Referral', 'Basic Needs - Information Referral', 'Other', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=7
('Utility Coordination - ROW', 'Utility Coordination - ROW', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=7
('ZZ Corridor Program - Corridor Feedback', 'Corridor Feedback', 'Transportation', 'RETIRED_ALIAS', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=6
('PW - Street & Bridge General', 'Street and Bridge Miscellaneous', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=5
('Zzz_Speed Limit - Changes/Signs', 'Speed Limit Changes', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=5
('ZZZ - DO NOT USE - ERM - Harmful Algae', 'Harmful Algae', 'Watershed', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=5
('ACD - Private Hauler License Violation', 'Private Hauler License Violation', 'Code', 'CONFIRMED_RENAME', 0, 1, NULL),  -- n=5
('Zz_ATD - Construction Items in Right of Way', 'Construction Items in Right of Way', 'Transportation', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=4
('ATD - Traffic Engineering - General', 'Traffic Engineering - General', 'Transportation', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=4
('HSEM Heat Advisory', 'Heat Advisory', 'Other', 'CONFIRMED_RENAME', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=4
('AEM - Heat Advisory', 'Heat Advisory', 'Other', 'CONFIRMED_RENAME', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=4
('ZZZ ARR Street Sweeping', 'Street Sweeping', 'Solid Waste', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service.'),  -- n=3
('zCoyote Complaints', 'Coyote Complaints', 'Animal', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3
('ZZZ - Storm Drain Pipe Services', 'Storm Drain Services', 'Watershed', 'RETIRED_ALIAS', 0, 1, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3
('Telecommunication/Gas Utility Complaint', 'Telecom/Gas Utility Complaint', 'Utilities', 'CONCURRENT', 0, 1, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge.'),  -- n=3
('ZZ Community Connections - Coronavirus', 'Coronavirus Complaint', 'Code', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Event-driven volume. Excluded from degradation ranking.'),  -- n=2
('ZZAFD - Fireworks Complaint', 'Fireworks Complaint', 'Public Safety', 'RETIRED_ALIAS', 1, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Event-driven volume. Excluded from degradation ranking.'),  -- n=2
('ZZ CRM - Configuration Test Francois', 'CRM - Configuration Test Francois', 'Test', 'EXCLUDED_TEST', 0, 0, 'Retired label (ZZ-prefixed in CRM); maps to the live canonical service. Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=2
('Emergency Vehicle Preemption Device', 'Emergency Vehicle Preemption Device', 'Transportation', 'SINGLETON', 0, 1, NULL),  -- n=2
('AW - Emergency Water Issues', 'Emergency Water Issues', 'Utilities', 'SINGLETON', 0, 1, NULL),  -- n=2
('Austin Code - Woodridge Apt', 'Woodridge Apt', 'Code', 'SINGLETON', 0, 0, 'Informational/internal workflow, not a resident service. Excluded from trend.'),  -- n=2
('ACD - Coronavirus', 'Coronavirus Complaint', 'Code', 'CONCURRENT', 1, 0, 'Overlaps in time with another label for this service. Run the comparability test (04b) before trusting the merge. Event-driven volume. Excluded from degradation ranking.'),  -- n=1
('Heat Advisory', 'Heat Advisory', 'Other', 'CONFIRMED_RENAME', 1, 0, 'Event-driven volume. Excluded from degradation ranking.'),  -- n=1
('Dead Bird', 'Dead Bird', 'Animal', 'SINGLETON', 0, 1, NULL)  -- n=1
GO

/* ------------------------------------------------------------
   Cutover events -- for chart annotations. Each is a date on
   which a batch of labels ended and their successors began.
   ------------------------------------------------------------ */
DROP TABLE IF EXISTS dw.cutover_events;
CREATE TABLE dw.cutover_events (
    event_date  DATE          NOT NULL PRIMARY KEY,
    event_name  NVARCHAR(100) NOT NULL,
    description NVARCHAR(400) NOT NULL,
    affects     NVARCHAR(100) NOT NULL
);
INSERT INTO dw.cutover_events VALUES
('2021-10-25', 'ARR label retirement',       'Austin Resource Recovery retires legacy labels (all ZZZ ARR labels end this day) and rebuilds its category scheme through Jun 2022.', 'Solid Waste'),
('2022-08-03', 'ATD prefix adoption',        'Transportation labels gain the "ATD - " prefix; unprefixed originals end within days.', 'Transportation'),
('2023-02-01', 'Winter Storm Mara',          'Ice storm. ~63k requests in Feb 2023 vs ~20k monthly norm; storm debris collection dominates 2023 volume.', 'Solid Waste, Transportation'),
('2023-06-02', 'CRM migration',              'Legacy Public Works, Animal Services and Austin Code labels end within three days; successor labels begin.', 'All'),
('2024-10-11', 'ATD/SBO/PWD merge into TPW', 'Transportation and Public Works formed. Every ATD/SBO/PWD label ends 10/07-10/13; TPW twin starts 10/08-10/14.', 'Transportation');
GO

/* ------------------------------------------------------------
   Coverage and sanity.
   ------------------------------------------------------------ */
SELECT COUNT(*) AS total_requests,
       SUM(CASE WHEN m.sr_type_desc IS NOT NULL THEN 1 ELSE 0 END) AS mapped,
       CAST(100.0 * SUM(CASE WHEN m.sr_type_desc IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_mapped,
       SUM(CASE WHEN m.in_trend = 1 THEN 1 ELSE 0 END) AS in_trend_rows,
       CAST(100.0 * SUM(CASE WHEN m.in_trend = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS pct_in_trend
FROM dw.sr s LEFT JOIN dw.sr_type_mapping m ON m.sr_type_desc = s.sr_type_desc;

-- Any raw label the mapping does not know about (should be empty; will fill as the city adds types)
SELECT s.sr_type_desc, COUNT(*) AS n
FROM dw.sr s LEFT JOIN dw.sr_type_mapping m ON m.sr_type_desc = s.sr_type_desc
WHERE m.sr_type_desc IS NULL GROUP BY s.sr_type_desc ORDER BY n DESC;

-- Basis summary for the methodology page
SELECT mapping_basis, COUNT(*) AS labels, SUM(n) AS requests
FROM dw.sr_type_mapping m
JOIN (SELECT sr_type_desc, COUNT(*) AS n FROM dw.sr GROUP BY sr_type_desc) c ON c.sr_type_desc = m.sr_type_desc
GROUP BY mapping_basis ORDER BY requests DESC;
GO
