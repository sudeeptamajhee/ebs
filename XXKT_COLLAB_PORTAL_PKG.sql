create or replace PACKAGE XXKT_COLLAB_PORTAL_PKG
/* $Header: XXKT_COLLAB_PORTAL_PKG $120.12.12010000.3 2019/12/17 00:00:00 sysadmin  */
-- +============================================================================================+
-- |                   (c) Copyright Xxxxxx Technologies,Santa Rosa USA                       |
-- |                                All Rights Reserved                                         |
-- +============================================================================================+
-- | $Header:$                                                                                  |
-- |                                                                                            |
-- | PROGRAM NAME    : XXKT_COLLAB_PORTAL_PKG                                                   |
-- |                                                                                            |
-- | DESCRIPTION     : Package Specification for Xxxxxx Collaboration Platform                |
--                                                                                              |
-- | USAGE           : sqlplus <APPS_Username>/<APPS_Password> @XXKT_COLLAB_PORTAL_PKG.sql      |
-- |                                                                                            |
-- | CAUTION/WARNINGS: Run under APPS Schema                                                    |
-- |                                                                                            |
-- | HISTORY                                                                                    |
-- | =======                                                                                    |
-- | Version  Date         Author                   Remarks                                     |
-- | -------  ----------   --------------------     --------------------------------------------|
-- | DRAFT    17-DEC-2019  Xxxxxx Yyyyyy            Initial Version                             |
-- +============================================================================================+
AUTHID CURRENT_USER AS
	TYPE XX_SEARCH_CRITERIA_REC IS RECORD (
		V_ROLE	                        VARCHAR2(100),
		V_ROLE_ID 	                    VARCHAR2(50),
		V_ROLE_VALUE 	                VARCHAR2(200)
	);

	TYPE XX_SEARCH_CRITERIA_TBL IS TABLE OF 
        XX_SEARCH_CRITERIA_REC INDEX BY BINARY_INTEGER;

     TYPE XX_FORECAST_COMMIT_REC IS RECORD (
        V_PRODUCT                       XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
		V_WEEK                          XXKT_RR_IRP_EXTRACT.WEEK_ID%TYPE,
        V_MONDAY                        XXKT_RR_IRP_EXTRACT.DEMAND_DATE%TYPE,
        V_YEAR                          NUMBER,
        V_NON_GSA_FORECAST              XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_NON_GSA_COMMIT                XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_NON_GSA_ADJUSTMENT            XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_FORECAST                  XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_COMMIT                    XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_ADJUSTMENT                XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_FORECAST                      XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_COMMIT                        XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_ADJUSTMENT                    XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_BUFFER                        XXKT_RR_IRP_EXTRACT.REQ_PLAN_BUFFER%TYPE,
        V_BUFFER_OPT_ADJ                XXKT_RR_IRP_EXTRACT.REQ_PLAN_BUFFER_OPT_ADJ%TYPE,
        V_ORIGINAL_FORECAST             XXKT_RR_IRP_EXTRACT.ORIGINAL_IRP_TOTAL_ORIGINAL%TYPE,
        V_FINAL_FORECAST                XXKT_RR_IRP_EXTRACT.FINAL_IRP_TOTAL_FINAL%TYPE,
        V_VARIANCE                      XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_ADJUSTMENT_TYPE               VARCHAR2(50),
        V_ADJUSTMENT_COMMENT            VARCHAR2(500),
        V_ORG                           XXKT_COLLAB_ITEM_MASTER.PART_SITE%TYPE,
        V_BU                            XXKT_COLLAB_ITEM_MASTER.BU%TYPE,
        V_BUILD_TYPE                    XXKT_COLLAB_ITEM_MASTER.BUILD_TYPE%TYPE
	);

    TYPE XX_FORECAST_COMMIT_TBL IS TABLE OF 
        XX_FORECAST_COMMIT_REC INDEX BY BINARY_INTEGER;

    TYPE XX_FORECAST_COMPARISON_REC IS RECORD (
        V_CODE                 	        VARCHAR2(100),
        V_NAME					        VARCHAR2(100),
        V_NO_OF_EXCEPTIONS		        NUMBER,
        V_EXCEPTION_QUANTITY	        NUMBER
    );

    TYPE XX_FORECAST_COMPARISON_TBL IS TABLE OF 
        XX_FORECAST_COMPARISON_REC INDEX BY BINARY_INTEGER;

    TYPE XX_FORECAST_VS_COMMIT_REC IS RECORD(
        V_TOTAL_FORECAST		        NUMBER,
        V_TOTAL_COMMIT			        NUMBER
    );

    TYPE XX_FORECAST_VS_COMMIT_TBL IS TABLE OF 
        XX_FORECAST_VS_COMMIT_REC INDEX BY BINARY_INTEGER;

    TYPE XX_FORECAST_COMMIT_RECEIVE_REC IS RECORD(
        V_VIEW                          VARCHAR2(20),
        V_FORECAST_DATE                 VARCHAR2(50),
        V_TOTAL_FORECAST		        NUMBER,
        V_TOTAL_COMMIT			        NUMBER,
        V_TOTAL_RECEIVED		        NUMBER
    );

    TYPE XX_FORECAST_COMMIT_RECEIVE_TBL IS TABLE OF 
        XX_FORECAST_COMMIT_RECEIVE_REC INDEX BY BINARY_INTEGER;

    TYPE XX_UNPLANNED_REQUEST_REC IS RECORD(
        V_PRODUCT_FAMILY		        VARCHAR2(200),
        V_PRODUCT_LINE			        VARCHAR2(200),
        V_PRODUCT				        VARCHAR2(200),
        V_REQUEST_DATE		            DATE,
        V_REQUEST_QUANTITY	            NUMBER,
        V_REQUEST_TYPE		            VARCHAR2(50),
        V_REQUEST_COMMENTS	            VARCHAR2(100),
        V_APPROVER				        VARCHAR2(100)
    );

    TYPE XX_UNPLANNED_REQUEST_TBL IS TABLE OF 
        XX_UNPLANNED_REQUEST_REC INDEX BY BINARY_INTEGER;

    TYPE ARRAY_OF_PLANNER_CODE IS TABLE OF VARCHAR2(200);
    
    TYPE XX_USER_PREFERENCE_REC IS RECORD (
        V_USER_ID                       XXKT_COLLAB_USER_PREFERENCE.USER_ID%TYPE,
        V_USER_NAME                     XXKT_COLLAB_USER_PREFERENCE.USER_NAME%TYPE,
        V_PREFERENCE_NAME               XXKT_COLLAB_USER_PREFERENCE.PREFERENCE_NAME%TYPE,
        V_PREFERENCE_VALUE              XXKT_COLLAB_USER_PREFERENCE.PREFERENCE_VALUE%TYPE
    );

    TYPE XX_USER_PREFERENCE_TBL IS TABLE OF 
        XX_USER_PREFERENCE_REC INDEX BY BINARY_INTEGER;

    TYPE XX_OPEN_TASK_REC IS RECORD (
        V_TASK_REQUEST_ID               XXKT_COLLAB_TASK_DETAIL.TASK_REQUEST_ID%TYPE,
        V_TASK_APPROVAL_ID              XXKT_COLLAB_TASK_DETAIL.TASK_APPROVAL_ID%TYPE,
        V_PRODUCT                       XXKT_COLLAB_TASK_DETAIL.PRODUCT%TYPE,
        V_FORECAST_DATE                 XXKT_COLLAB_TASK_DETAIL.FORECAST_DATE%TYPE,
        V_VARIANCES                     XXKT_COLLAB_TASK_DETAIL.VARIANCES%TYPE,
        V_TASK_STATUS                   XXKT_COLLAB_TASK_DETAIL.TASK_STATUS%TYPE,
        V_FORM                          XXKT_COLLAB_TASK_DETAIL.TASK_FROM%TYPE,
        V_TO                            XXKT_COLLAB_TASK_DETAIL.TASK_TO%TYPE,
        V_SUBJECT                       XXKT_COLLAB_TASK_DETAIL.TASK_SUBJECT%TYPE,
        V_MESSAGE                       XXKT_COLLAB_TASK_DETAIL.TASK_MESSAGE%TYPE
    );

    TYPE XX_OPEN_TASK_TBL IS TABLE OF 
        XX_OPEN_TASK_REC INDEX BY BINARY_INTEGER;

    TYPE XX_OPEN_POS_REC IS RECORD (
        V_CODE                          VARCHAR2(20),
        V_NAME                          VARCHAR2(100),
        V_NO_OF_OPEN_POS                NUMBER,
        V_OPEN_POS_QUANTITY             NUMBER
    );

    TYPE XX_OPEN_POS_TBL IS TABLE OF
        XX_OPEN_POS_REC INDEX BY BINARY_INTEGER;
    
    TYPE XX_FORECAST_WEEK_COMP_REC IS RECORD (
        V_PRODUCT                       XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        V_WEEK_ID						XXKT_RR_IRP_EXTRACT.WEEK_ID%TYPE,	
        V_FORECAST_DATE              	XXKT_RR_IRP_EXTRACT.DEMAND_DATE%TYPE,	
        V_NON_GSA_REQ		            XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_NON_GSA_ADJ		            XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_NON_GSA_COMMIT             	XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_REQ	                	XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_ADJ               		XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_GSA_COMMIT               		XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_FORECAST_REQ               	XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_FORECAST_ADJ               	XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        V_FORECAST_COMMIT            	XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE
    );

    TYPE XX_FORECAST_WEEK_COMP_TBL IS TABLE OF 
		XX_FORECAST_WEEK_COMP_REC INDEX BY BINARY_INTEGER;

    PROCEDURE VALIDATE_FND_LOGIN(
        P_USER_NAME                     IN VARCHAR2,
        O_USER_ID                       OUT NUMBER,
        O_USER_TYPE                     OUT VARCHAR2,
        O_DESCRIPTION                   OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE GET_SEARCH_CRITERIAS(
		P_LOGIN_TYPE 		            IN 	VARCHAR2,
		P_LOGIN_VALUE 		            IN 	VARCHAR2,
		XX_SEARCH_CRITERIA_OUT 	        OUT XX_SEARCH_CRITERIA_TBL,
        O_ERR_MSG                       OUT VARCHAR2
	); 

    PROCEDURE GET_FORECAST_COMMIT_VAR_ARR(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE                   IN 	VARCHAR2,
        P_VIEW                          IN  VARCHAR2,
        P_PLANNER                       IN  ARRAY_OF_PLANNER_CODE,
        P_VENDOR                        IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY                IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE                  IN  VARCHAR2,
        P_PRODUCT                       IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT                    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
        XX_FORECAST_COMMIT_OUT          OUT XX_FORECAST_COMMIT_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE GET_FORECAST_COMMIT_VARIANCE(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE                   IN 	VARCHAR2,
        P_VIEW                          IN  VARCHAR2,
        P_PLANNER                       IN  MTL_PLANNERS.PLANNER_CODE%TYPE,
        P_VENDOR                        IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY                IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE                  IN  VARCHAR2,
        P_PRODUCT                       IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT                    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
        XX_FORECAST_COMMIT_OUT          OUT XX_FORECAST_COMMIT_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE UPDATE_FORECAST_ADJUSTMENTS(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE                   IN 	VARCHAR2,
        P_VIEW                          IN 	VARCHAR2,
        P_PLANNER           		    IN  MTL_PLANNERS.PLANNER_CODE%TYPE,
        P_VENDOR            		    IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY    		    IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE      		    IN  VARCHAR2,
        P_PRODUCT           		    IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT        		    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
        XX_FORECAST_ADJ_DETAIL_IN 	    IN 	XX_FORECAST_COMMIT_TBL,
        O_SUC_MSG					    OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE UPDATE_CM_COMMITS(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE                   IN 	VARCHAR2,
        P_VIEW                          IN 	VARCHAR2,
        P_PLANNER           		    IN  MTL_PLANNERS.PLANNER_CODE%TYPE,
        P_VENDOR            		    IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY    		    IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE      		    IN  VARCHAR2,
        P_PRODUCT           		    IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT        		    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
        XX_CM_COMMITS_DETAIL_IN		    IN 	XX_FORECAST_COMMIT_TBL,
        O_SUC_MSG					    OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE GET_DASHBOARD_INFORMATION(
        P_LOGIN_TYPE    				IN 	VARCHAR2,
        P_LOGIN_VALUE					IN 	VARCHAR2,
        XX_FORECAST_COMPARISON_OUT      OUT XX_FORECAST_COMPARISON_TBL,
        XX_FORECAST_VS_COMMIT_OUT		OUT XX_FORECAST_VS_COMMIT_TBL,
        XX_FCR_OUT	            	    OUT XX_FORECAST_COMMIT_RECEIVE_TBL,
        XX_OPEN_TASK_OUT                OUT XX_OPEN_TASK_TBL,
        XX_OPEN_POS_OUT                 OUT XX_OPEN_POS_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE LOAD_SUBMITTED_REQUESTS(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_SUBMITTED_REQUEST_OUT        OUT	XX_UNPLANNED_REQUEST_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE SAVE_UNPLANNED_REQUEST(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_NEW_REQUEST_IN	            IN	XX_UNPLANNED_REQUEST_TBL,
        XX_REMOVE_REQUEST_IN	        IN	XX_UNPLANNED_REQUEST_TBL,
        O_SUC_MSG					    OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE CREATE_UPDATE_TASK(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        P_ACTION                        IN  VARCHAR2,
        P_PLANNER                       IN  VARCHAR2,
        P_FROM                          IN 	VARCHAR2,
        P_SUPPLIER                      IN  VARCHAR2,
        P_TO                            IN 	VARCHAR2,
        P_PRODUCT                       IN 	VARCHAR2,
        P_FORECAST_DATE                 IN 	DATE,
        P_VARIANCE                      IN  NUMBER,
        P_STATUS                        IN 	VARCHAR2,
        P_SUBJECT                       IN 	VARCHAR2,
        P_MESSAGE                       IN 	VARCHAR2,
        P_REQUEST_ID                    IN 	VARCHAR2,
        O_APPROVAL_ID	                OUT	VARCHAR2,
        O_SUC_MSG                       OUT	VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE GET_USER_PREFERENCES(
        P_USER_NAME                     IN  XXKT_COLLAB_USER_PREFERENCE.USER_NAME%TYPE,
        P_USER_ID                       IN  XXKT_COLLAB_USER_PREFERENCE.USER_ID%TYPE,
        XX_USER_PREFERENCE_OUT          OUT XX_USER_PREFERENCE_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE UPDATE_USER_PREFERENCES(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_USER_PREFERENCE_IN           IN  XX_USER_PREFERENCE_TBL,
        O_SUC_MSG                       OUT	VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE AD_HOC_FORECAST(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        P_VIEW                          IN  VARCHAR2,
        P_PLANNER                       IN  MTL_PLANNERS.PLANNER_CODE%TYPE,
        P_VENDOR                        IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY                IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE                  IN  VARCHAR2,
        P_PRODUCT                       IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT                    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
        P_FORECAST_DATE                 IN  XXKT_RR_IRP_EXTRACT.DEMAND_DATE%TYPE,
        P_NON_GSA_ADJ_QTY               IN  XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        P_GSA_ADJ_QTY                   IN  XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        P_FORECAST_ADJ_QTY              IN  XXKT_RR_IRP_EXTRACT.REQ_PLAN_FORECAST%TYPE,
        P_ADJ_TYPE                      IN  VARCHAR2,
        P_ADJ_COMMENT                   IN  VARCHAR2,
        O_SUC_MSG                       OUT	VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    );

    PROCEDURE GET_FORECAST_INFO_COMPARISON(
        P_LOGIN_TYPE                    IN 	VARCHAR2,
        P_LOGIN_VALUE                   IN 	VARCHAR2,
        P_VIEW                          IN  VARCHAR2,
        P_PLANNER                       IN  MTL_PLANNERS.PLANNER_CODE%TYPE,
        P_VENDOR                        IN  XXKT_RR_IRP_EXTRACT.SUPPLIER%TYPE,
        P_PRODUCT_FAMILY                IN  XXKT_RR_IRP_EXTRACT.PRODUCT_FAMILY%TYPE,
        P_PRODUCT_LINE                  IN  VARCHAR2,
        P_PRODUCT                       IN  XXKT_RR_IRP_EXTRACT.COMPONENT_PART%TYPE,
        P_DEPARTMENT                    IN  XXKT_COLLAB_ITEM_MASTER.DEPT%TYPE,
--        P_WEEK1YR                       IN  NUMBER,
--        P_WEEK1WK                       IN  NUMBER,
--        P_WEEK2YR                       IN  NUMBER,
--        P_WEEK2WK                       IN  NUMBER,
        XX_FC_LAST_WEEK_OUT             OUT XX_FORECAST_WEEK_COMP_TBL,
        XX_FC_CURR_WEEK_OUT             OUT XX_FORECAST_WEEK_COMP_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    );

END XXKT_COLLAB_PORTAL_PKG;
