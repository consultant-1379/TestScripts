from collections import OrderedDict

ONCE_OFF_BEFORE_STABILITY = OrderedDict()
SETUP = OrderedDict()
EXCLUSIVE = OrderedDict()
NON_EXCLUSIVE = OrderedDict()
PLACEHOLDERS = OrderedDict()

# To start run the following on the workload VM:
# workload start all --schedule /opt/ericsson/enmutils/schedules/rv_full_schedule.py

# APPLICATION                          PROFILES                                    START_SLEEP,  STOP_SLEEP(SEC)

#ONCE_OFF_BEFORE_STABILITY.update(
#    {"ONCE_BEFORE_STABILITY":            [("NODESEC_03",                                20,     10),
#                                          ("NODESEC_01",                                20,     10),
#                                          ("NODESEC_04",                                20,     10),
#                                          ("NODESEC_08",                                20,     10),
#                                          ("NODESEC_11",                                20,     10),
#                                          ("NODESEC_12",                                20,     10),
#                                          ("NODESEC_13",                                20,     10),
#                                          ("NODESEC_14",                                20,     10)]})
#  -------------------------------------------------------------------------------------------------------
SETUP.update(
    {"SETUP":                            [("AP_SETUP",                                  5,      10),
#                                          ("AP_01",                                     300,      10),
                                          ("CMIMPORT_04",                               30,     10),
                                          ("CMIMPORT_02",                               30,     10),
                                          ("SHM_SETUP",                                 5,      10),
                                          ("NHM_SETUP",                                 5,      10),
                                          ("CMIMPORT_07",                               5,      10),
                                          ("FM_0506",                                   5,      10),
                                          ("PM_01",                                     30,     30),
                                          ("AID_SETUP",                                 5,      10),
                                          ("CMEXPORT_06",                               5,      10)]})
#  -------------------------------------------------------------------------------------------------------
EXCLUSIVE.update(
    {})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
     {"FM":                               [("FM_01",                                    10,    10),
                                           ("FM_02",                                    10,    10),
                                           ("FM_03",                                    10,    10),
#                                           ("FM_05",                                    10,    10),
                                           ("FM_08",                                    10,    10),
                                           ("FM_09",                                    10,    10),
                                           ("FM_10",                                    10,    10),
                                           ("FM_11",                                    10,    10),
#                                           ("FM_12",                                    10,    10),
                                           ("FM_14",                                    10,    10),
                                           ("FM_15",                                    10,    10),
#                                           ("FM_21",                                    10,    10),
                                           ("FM_20",                                    10,    10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"CMCLI":                            [("CMCLI_01",                                  5,      10),
                                          ("CMCLI_02",                                  5,      10),
                                          ("CMCLI_03",                                  5,      10)]})
# --------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"CMSYNC":                           [("CMSYNC_01",                                 10,     10),
                                          ("CMSYNC_02",                                 10,     10),
                                          ("CMSYNC_03",                                 10,     10),
                                          ("CMSYNC_04",                                 10,     10),
                                          ("CMSYNC_05",                                 10,     10),
#                                          ("CMSYNC_08",                                 10,     10),
#                                          ("CMSYNC_09",                                 10,     10),
#                                          ("CMSYNC_10",                                 10,     10),
                                          ("CMSYNC_06",                                 10,     10)]})
# --------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"SHM":                              [("SHM_01",                                    20,     10),
                                          ("SHM_02",                                    20,     10),
#                                          ("SHM_03",                                    20,     10),
                                          ("SHM_04",                                    20,     10),
#                                          ("SHM_05",                                    20,     10),
#                                          ("SHM_06",                                    20,     10),
                                          ("SHM_07",                                    20,     10),
                                          ("SHM_08",                                    20,     10),
#                                          ("SHM_09",                                    20,     10),
                                          ("SHM_10",                                    20,     10),
#                                          ("SHM_11",                                    20,     10),
#                                          ("SHM_12",                                    20,     10),
                                          ("SHM_13",                                    20,     10),
                                          ("SHM_14",                                    20,     10),
#                                          ("SHM_15",                                    20,     10),
#                                          ("SHM_16",                                    20,     10),
#                                          ("SHM_18",                                    20,     10),
                                          ("SHM_19",                                    20,     10),
                                          ("SHM_20",                                    20,     10),
                                          ("SHM_21",                                    20,     10)]})

#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"FMX":                              [("FMX_01",                                    10,     10),
                                          ("FMX_05",                                    10,     10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"LOGVIEWER":                        [("LOGVIEWER_01",                              5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"NETEX":                            [("NETEX_02",                                  60*2,   10),
#                                          ("NETEX_03",                                  60*2,   10),
                                          ("NETEX_01",                                  60,     10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"NHM":                              [("NHM_03",                                    60*2,   10),
                                          ("NHM_04",                                    60*2,   10),
                                          ("NHM_06",                                    60*2,   10),
                                          ("NHM_07",                                    60*2,   10),
                                          ("NHM_08",                                    60*2,   10),
                                          ("NHM_09",                                    60*2,   10),
                                          ("NHM_10",                                    60*2,   10),
                                          ("NHM_11",                                    60*2,   10)]})
# -------------------------------------------------------------------------------------------------------
#NON_EXCLUSIVE.update(
#    {"NODESEC":                          [("NODESEC_02",                                20,     10),
#                                          ("NODESEC_09",                                20,     10),
#                                          ("NODESEC_10",                                20,     10)]})
# -------------------------------------------------------------------------------------------------------
#NON_EXCLUSIVE.update(
#    {"EBSM":                             [("EBSM_04",                                   5,      10),
#                                          ("EBSM_05",                                   5,      10)]})
#  -------------------------------------------------------------------------------------------------------
#NON_EXCLUSIVE.update(
#    {"EBSL":                             [("EBSL_04",                                   5,      10)]})
#
#  -------------------------------------------------------------------------------------------------------
#NON_EXCLUSIVE.update(
#    {"CELLMGT":                          [("CELLMGT_01",                                5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"AP":                               [("AP_10",                                     5,      10),
                                          ("AP_11",                                     5,      10),
                                          ("AP_12",                                     5,      10),
                                          ("AP_13",                                     5,      10),
                                          ("AP_14",                                     5,      10),
                                          ("AP_15",                                     5,      10),
                                          ("AP_16",                                     5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"AID":                              [("AID_01",                                    5,      10),
                                          ("AID_02",                                    5,      10),
                                          ("AID_03",                                    5,      10)]})

#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"NHC":                              [("NHC_01",                                    5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"AMOS":                             [("AMOS_01",                                   5,      10),
#										  ("AMOS_SESSIONS",                             5,      10),
                                          ("AMOS_02",                                   5,      10),
                                          ("AMOS_03",                                   5,      10),
                                          ("AMOS_04",                                   5,      10),
                                          ("AMOS_05",                                   5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"DOC":                              [("DOC_01",                                    5,      10)]})
#  -------------------------------------------------------------------------------------------------------
#NON_EXCLUSIVE.update(
#    {"EM":                               [("EM_01",                                     5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"ESM":                              [("ESM_01",                                    5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"CLI_MON":                          [("CLI_MON_01",                                10,     10),
                                          ("CLI_MON_02",                                10,     10),
                                          ("CLI_MON_03",                                10,     10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"CMIMPORT":                         [("CMIMPORT_01",                               30,     10),
                                          ("CMIMPORT_03",                               30,     10),
                                          ("CMIMPORT_05",                               30,     10),
                                          ("CMIMPORT_09",                               30,     10),
#                                          ("CMIMPORT_10",                               60,     10),
                                          ("CMIMPORT_08",                               60,     10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"CMEXPORT":                         [("CMEXPORT_01",                               20,     10),
                                          ("CMEXPORT_02",                               20,     10),
                                          ("CMEXPORT_03",                               20,     10),
                                          ("CMEXPORT_05",                               20,     10),
                                          ("CMEXPORT_07",                               20,     10),
                                          ("CMEXPORT_08",                               20,     10),
                                          ("CMEXPORT_11",                               20,     10),
                                          ("CMEXPORT_12",                               20,     10),
                                          ("CMEXPORT_13",                               20,     10),
                                          ("CMEXPORT_14",                               20,     10),
                                          ("CMEXPORT_16",                               20,     10),
                                          ("CMEXPORT_17",                               20,     10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"TOP":                              [("TOP_01",                                    5,      10)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"PM":                               [("PM_15",                                     60*1,   10),
                                          ("PM_17",                                     60*1,   10),
                                          ("PM_20",                                     60*5,   60),
#                                          ("PM_22",                                     60*5,   60),
                                          ("PM_25",                                     60*5,  60*2),
                                          ("PM_02",                                     60*10,  60*5),
#                                          ("PM_31",                                     60*5,   60*3),
                                          ("PM_16",                                     60*5,   60*3),
#                                          ("PM_34",                                     60*5,   60*3),
                                          ("PM_03",                                     60*15,  60*5),
                                          ("PM_24",                                     60*5,   60*2),
                                          ("PM_04",                                     60*10,  60*5),
                                          ("PM_19",                                     60*5,   60*3),
#                                          ("PM_29",                                     60*3,   60*3),
                                          ("PM_30",                                     60*3,   60*3),
#                                          ("PM_11",                                     60*10,  60*5),
                                          ("PM_12",                                     60*3,   60*1),
                                          ("PM_13",                                     60*3,   60*1),
#                                          ("PM_32",                                     60*5,   60*2),
#                                          ("PM_27",                                     60*5,   60*1),
#                                          ("PM_28",                                     60*5,   60*1),
#                                          ("PM_33",                                     60*5,   60*1),
                                          ("PM_26",                                     30,     60*1),
#                                          ("PM_10",                                     60,     10),
                                          ("PM_06",                                     30,     60*1)]})
#  -------------------------------------------------------------------------------------------------------
NON_EXCLUSIVE.update(
    {"EBSM":                              [("EBSM_04",                                  60*5,     60)]})
#  -------------------------------------------------------------------------------------------------------
# NON_EXCLUSIVE.update(
    {"SECUI":                             [("SECUI_02",                                  60*5,      10),
#                                         ("SECUI_04",                                  5,         10),
                                          ("SECUI_01",                                  60*5,      10)]})
#  -------------------------------------------------------------------------------------------------------
#PLACEHOLDERS.update(
#    {"PLACEHOLDERS":                     [("FMX_02",                                    1,     1),
#                                          ("FMX_03",                                    1,     1),
#                                          ("FMX_04",                                    1,     1),
#                                          ("EBSM_01",                                   1,     1),
#                                          ("EBSM_02",                                   1,     1),
#                                          ("EBSM_03",                                   1,     1),
#                                          ("CMSYNC_07",                                 1,     1),
#                                          ("CMEXPORT_15",                               1,     1),
#                                          ("CMIMPORT_06",                               1,     1),
#                                          ("NODESEC_05",                                1,     1),
#                                          ("NODESEC_06",                                1,     1),
#                                          ("BUR_01",                                    1,     1),
#                                          ("BUR_02",                                    1,     1),
#                                          ("MIGRATION_01",                              1,     1),
#                                          ("MIGRATION_02",                              1,     1),
#                                          ("MIGRATION_03",                              1,     1),
#                                          ("ESM_02",                                    1,     1),
#                                          ("LCM_01",                                    1,     1),
#                                          ('PM_99',                                     1,     1),
#                                          ("FM_04",                                     1,     1)]})

WORKLOAD = [ONCE_OFF_BEFORE_STABILITY, SETUP, EXCLUSIVE, NON_EXCLUSIVE, PLACEHOLDERS]
