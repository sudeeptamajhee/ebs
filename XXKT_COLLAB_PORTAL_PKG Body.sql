create or replace PACKAGE BODY XXKT_COLLAB_PORTAL_PKG
AS    
    /*#############################VALIDATE_FND_LOGIN#############################*/

	PROCEDURE VALIDATE_FND_LOGIN(
        P_USER_NAME                     IN VARCHAR2,
        O_USER_ID                       OUT NUMBER,
        O_USER_TYPE                     OUT VARCHAR2,
        O_DESCRIPTION                   OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    )
    IS
        L_PLANNER_ID                    NUMBER;
        L_SUPPLIER_ID                   NUMBER;
    BEGIN
        SELECT  EMPLOYEE_ID, SUPPLIER_ID, DESCRIPTION
        INTO    L_PLANNER_ID, L_SUPPLIER_ID, O_DESCRIPTION
        FROM    FND_USER 
        WHERE   USER_NAME = P_USER_NAME;

        IF L_PLANNER_ID IS NOT NULL THEN                    -- PLANNER
            O_USER_ID := L_PLANNER_ID;
            O_USER_TYPE := 'PLNR';
        ELSIF L_SUPPLIER_ID IS NOT NULL THEN                -- SUPPLIER
            O_USER_TYPE := 'CM';         
            BEGIN
                SELECT  DISTINCT C.VENDOR_ID INTO O_USER_ID
                FROM    FND_USER A, AP_SUPPLIER_CONTACTS B, AP_SUPPLIER_SITES_ALL C 
                WHERE   B.VENDOR_CONTACT_ID = A.SUPPLIER_ID 
                AND     C.VENDOR_SITE_ID    = B.VENDOR_SITE_ID 
                AND     B.VENDOR_CONTACT_ID = L_SUPPLIER_ID;
            EXCEPTION WHEN OTHERS THEN
                O_USER_ID := L_SUPPLIER_ID;
            END;
        ELSIF L_PLANNER_ID IS NOT NULL 
                AND L_SUPPLIER_ID IS NOT NULL THEN          -- REQUESTER
            O_USER_ID := L_PLANNER_ID;
            O_USER_TYPE := 'REQ';
        ELSE
            O_ERR_MSG := 'Invalid Username';
       END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('VALIDATE_FND_LOGIN > ' || O_ERR_MSG);
    END VALIDATE_FND_LOGIN;

    /*#############################GET_SEARCH_CRITERIAS#############################*/

	PROCEDURE GET_SEARCH_CRITERIAS(
		P_LOGIN_TYPE 		            IN 	VARCHAR2,
		P_LOGIN_VALUE 		            IN 	VARCHAR2,
		XX_SEARCH_CRITERIA_OUT 	        OUT XX_SEARCH_CRITERIA_TBL,
        O_ERR_MSG                       OUT VARCHAR2
	)
	IS
    BEGIN
        IF P_LOGIN_TYPE = 'PLNR' THEN                       -- PLANNER
            SELECT  X.V_ROLE, X.V_ROLE_ID, X.V_ROLE_VALUE
            BULK    COLLECT 
            INTO    XX_SEARCH_CRITERIA_OUT
            FROM(
                SELECT  'VENDOR' V_ROLE, TO_CHAR(VENDOR_ID) V_ROLE_ID, VENDOR_NAME V_ROLE_VALUE
                FROM    AP_SUPPLIERS 
                WHERE   VENDOR_ID IN (109420, 28306, 25917, 18025, 77523, 1388845)
              UNION
                SELECT  'PLANNER' V_ROLE, PLANNER_CODE V_ROLE_ID, DESCRIPTION V_ROLE_VALUE
                FROM    MTL_PLANNERS
                WHERE   (PLANNER_CODE LIKE '%CM'
                OR      PLANNER_CODE LIKE '%B2B')
                AND     ORGANIZATION_ID = 128
              UNION
                SELECT  DISTINCT 'PRODUCT', SUBSTR(PART_NAME, 1, 50), '' 
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   PART_NAME LIKE '33210%'
              UNION
                SELECT  DISTINCT 'PRODUCT_FAMILY', SUBSTR(PRODUCT_FAMILY, 1, 50), ''
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   PRODUCT_FAMILY IS NOT NULL
              UNION
                SELECT  DISTINCT 'DEPARTMENT', replace(replace(DEPT,CHR(10), ''), CHR(13),''), ''
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   DEPT IS NOT NULL
              UNION
                SELECT  DISTINCT 'PRODUCT_LINE', 'PL', ''
                FROM    DUAL
              UNION
                SELECT  'ADJ_TYPE', AR_VALUE, AR_VALUE
                FROM    XXKT_COLLAB_ADJ_RESN_DETAIL
                WHERE   AR_TYPE = 'A'
            ) X; 
        ELSIF P_LOGIN_TYPE = 'CM' THEN                      -- SUPPLIER
            SELECT  Y.V_ROLE, Y.V_ROLE_ID, Y.V_ROLE_VALUE 
            BULK    COLLECT 
            INTO    XX_SEARCH_CRITERIA_OUT
            FROM (
                SELECT  'VENDOR' V_ROLE, TO_CHAR(VENDOR_ID) V_ROLE_ID, VENDOR_NAME V_ROLE_VALUE
                FROM    AP_SUPPLIERS 
                WHERE   VENDOR_ID IN (109420, 28306, 25917, 18025, 77523, 1388845)
              UNION
                SELECT  'PLANNER' V_ROLE, PLANNER_CODE V_ROLE_ID, DESCRIPTION V_ROLE_VALUE
                FROM    MTL_PLANNERS
                WHERE   (PLANNER_CODE LIKE '%CM'
                OR      PLANNER_CODE LIKE '%B2B')
                AND     ORGANIZATION_ID = 128
              UNION
                SELECT  DISTINCT 'PRODUCT', SUBSTR(PART_NAME, 1, 50), '' 
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   PART_NAME LIKE '3350%'   
                OR      PART_NAME LIKE '3490%'              -- TEMP CODE
              UNION
                SELECT  DISTINCT 'PRODUCT_FAMILY', SUBSTR(PRODUCT_FAMILY, 1, 50), ''
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   PRODUCT_FAMILY IS NOT NULL
              UNION
                SELECT  DISTINCT 'DEPARTMENT', REPLACE(Replace(DEPT,CHR(10), ''), CHR(13), ''), ''
                FROM    XXKT_COLLAB_ITEM_MASTER
                WHERE   DEPT IS NOT NULL
              UNION
                SELECT  DISTINCT 'PRODUCT_LINE', 'PL', ''   -- TEMP CODE
                FROM    DUAL
             UNION
                SELECT  'RESN_TYPE', AR_VALUE, AR_VALUE
                FROM    XXKT_COLLAB_ADJ_RESN_DETAIL
                WHERE   AR_TYPE = 'R'
            ) Y;
		ELSE
			O_ERR_MSG := 'Invalid Usertype';
		END IF;
	EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_SEARCH_CRITERIAS > ' || O_ERR_MSG);
	END GET_SEARCH_CRITERIAS;

    /* ########################GET_FORECAST_COMMIT_VAR_ARR########################## */

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
    )
    IS
    BEGIN
        SELECT  RIE.COMPONENT_PART 								V_PRODUCT, 
                RIE.WEEK_ID 									V_WEEK, 
                RIE.DEMAND_DATE 								V_MONDAY, 
                TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'YYYY')) 	V_YEAR,
                NVL(RIE.REQ_PLAN_NON_GSA, 0) 					V_NON_GSA_FORECAST,
                NVL(CCC.NON_GSA_COMMIT_QTY, 0) 					V_NON_GSA_COMMIT, 
                NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) 				V_NON_GSA_ADJUSTMENT,
                NVL(RIE.REQ_PLAN_GSA, 0) 						V_GSA_FORECAST,
                NVL(CCC.GSA_COMMIT_QTY, 0) 						V_GSA_COMMIT, 
                NVL(CPA.REQ_PLAN_GSA_ADJ, 0) 					V_GSA_ADJUSTMENT,
                NVL(RIE.REQ_PLAN_FORECAST, 0) 					V_FORECAST,
                NVL(CCC.COMMIT_QUANTITY, 0) 					V_COMMIT, 
                NVL(CPA.ADJUSTMENT_QUANTITY, 0) 				V_ADJUSTMENT,
                NVL(RIE.REQ_PLAN_BUFFER, 0) 					V_BUFFER,
                NVL(RIE.REQ_PLAN_BUFFER_OPT_ADJ, 0) 			V_BUFFER_OPT_ADJ,
                NVL(RIE.ORIGINAL_IRP_TOTAL_ORIGINAL, 0) 		V_ORIGINAL_FORECAST,
                NVL(RIE.FINAL_IRP_TOTAL_FINAL, 0) 				V_FINAL_FORECAST,
                ((NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                  NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0)) -
                 (NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                )  												V_VARIANCE, 
                CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_TYPE
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_REASON
                END 											V_ADJUSTMENT_TYPE,
                CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_COMMENTS
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_COMMENTS
                END 											V_ADJUSTMENT_COMMENT,
                CIM.PART_SITE                                   V_ORG,
                CIM.BU                                          V_BU,
                CIM.BUILD_TYPE                                  V_BUILD_TYPE
                
        BULK    COLLECT 
        INTO    XX_FORECAST_COMMIT_OUT
        
        FROM    XXKT_RR_IRP_EXTRACT RIE, 
                XXKT_COLLAB_ITEM_MASTER CIM, 
                MTL_SYSTEM_ITEMS_B MSI,
                XXKT_COLLAB_CM_COMMITS CCC, 
                XXKT_COLLAB_PLNR_ADJUSTMENTS CPA
        WHERE   MSI.SEGMENT1 = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CIM.PART_NAME

        AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
        AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
        AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
        AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                        WHERE 	CCC1.PRODUCT = CCC.PRODUCT
                                                        AND 	CCC1.WEEK_ID = CCC.WEEK_ID
                                                        AND 	CCC1.DEMAND_DATE = CCC.DEMAND_DATE)

        AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
        AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
        AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
        AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                        WHERE 	CPA1.PRODUCT = CPA.PRODUCT
                                                        AND 	CPA1.WEEK_ID = CPA.WEEK_ID
                                                        AND 	CPA1.DEMAND_DATE = CPA.DEMAND_DATE)

        AND     MSI.ORGANIZATION_ID = 128
        AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
        AND     MSI.PLANNER_CODE IN (SELECT NVL(COLUMN_VALUE,PLANNER_CODE) FROM TABLE(P_PLANNER))
        AND     UPPER(REPLACE(RIE.SUPPLIER,'.','')) IN (SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                        FROM    AP_SUPPLIERS
                                                        WHERE   VENDOR_ID = P_VENDOR)
        AND     CIM.PART_NAME LIKE NVL('%'||P_PRODUCT||'%', CIM.PART_NAME)
        --AND     XXXX = NVL(P_PRODUCT_LINE, XXX)
        AND     CIM.PRODUCT_FAMILY = NVL(P_PRODUCT_FAMILY, CIM.PRODUCT_FAMILY)
        AND     REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),'') = NVL(P_DEPARTMENT, REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),''))
        ORDER BY RIE.COMPONENT_PART, RIE.DEMAND_DATE;

    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMMIT_VAR_ARR > ' || O_ERR_MSG);
    END GET_FORECAST_COMMIT_VAR_ARR;

    /*#############################GET_FORECAST_COMMIT_VARIANCE###################*/

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
    )
    IS
    BEGIN
        SELECT  RIE.COMPONENT_PART 								    V_PRODUCT, 
                CASE WHEN P_VIEW = 'WEEK'  THEN TO_CHAR(RIE.DEMAND_DATE, 'WW')
                     WHEN P_VIEW = 'MONTH' THEN TO_CHAR(RIE.DEMAND_DATE, 'MM')
                     WHEN P_VIEW = 'YEAR'  THEN TO_CHAR(RIE.DEMAND_DATE, 'YYYY')
                     ELSE TO_CHAR(RIE.DEMAND_DATE, 'WW')
                END          									    V_WEEK, 								 
                CASE WHEN P_VIEW = 'WEEK'  THEN RIE.DEMAND_DATE
                     WHEN P_VIEW = 'MONTH' THEN TRUNC(RIE.DEMAND_DATE, 'MONTH')
                     WHEN P_VIEW = 'YEAR'  THEN TRUNC(RIE.DEMAND_DATE, 'YEAR')
                     ELSE RIE.DEMAND_DATE                       
                END                                                 V_MONDAY,
                TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'YYYY')) 	    V_YEAR,
                SUM(NVL(RIE.REQ_PLAN_NON_GSA, 0)) 					V_NON_GSA_FORECAST,
                SUM(NVL(CCC.NON_GSA_COMMIT_QTY, 0)) 				V_NON_GSA_COMMIT, 
                SUM(NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0)) 				V_NON_GSA_ADJUSTMENT,
                SUM(NVL(RIE.REQ_PLAN_GSA, 0)) 						V_GSA_FORECAST, 
                SUM(NVL(CCC.GSA_COMMIT_QTY, 0)) 					V_GSA_COMMIT, 
                SUM(NVL(CPA.REQ_PLAN_GSA_ADJ, 0)) 					V_GSA_ADJUSTMENT,
                SUM(NVL(RIE.REQ_PLAN_FORECAST, 0)) 					V_FORECAST, 
                SUM(NVL(CCC.COMMIT_QUANTITY, 0)) 					V_COMMIT, 
                SUM(NVL(CPA.ADJUSTMENT_QUANTITY, 0)) 				V_ADJUSTMENT,
                SUM(NVL(RIE.REQ_PLAN_BUFFER, 0)) 					V_BUFFER, 
                SUM(NVL(RIE.REQ_PLAN_BUFFER_OPT_ADJ, 0)) 			V_BUFFER_OPT_ADJ,
                SUM(NVL(RIE.ORIGINAL_IRP_TOTAL_ORIGINAL, 0)) 		V_ORIGINAL_FORECAST, 
                SUM(NVL(RIE.FINAL_IRP_TOTAL_FINAL, 0)) 				V_FINAL_FORECAST,
                SUM((NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                  NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0)) -
                 (NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                )  												    V_VARIANCE, 
                CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_TYPE
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_REASON
                END 											    V_ADJUSTMENT_TYPE, 
                CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_COMMENTS
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_COMMENTS
                END 											    V_ADJUSTMENT_COMMENT,
                CIM.PART_SITE                                       V_ORG,
                CIM.BU                                              V_BU,
                CIM.BUILD_TYPE                                      V_BUILD_TYPE

        BULK    COLLECT 
        INTO    XX_FORECAST_COMMIT_OUT
        
        FROM    XXKT_RR_IRP_EXTRACT RIE, 
                XXKT_COLLAB_ITEM_MASTER CIM, 
                MTL_SYSTEM_ITEMS_B MSI,
                XXKT_COLLAB_CM_COMMITS CCC, 
                XXKT_COLLAB_PLNR_ADJUSTMENTS CPA
        WHERE   MSI.SEGMENT1 = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
        AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
        AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
        AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                        WHERE 	CCC1.PRODUCT = CCC.PRODUCT
                                                        AND 	CCC1.WEEK_ID = CCC.WEEK_ID
                                                        AND 	CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
        AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
        AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
        AND     RIE.WEEK_ID = TO_CHAR(SYSDATE, 'WW')
        AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
        AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                        WHERE 	CPA1.PRODUCT = CPA.PRODUCT
                                                        AND 	CPA1.WEEK_ID = CPA.WEEK_ID
                                                        AND 	CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
        AND     MSI.ORGANIZATION_ID = 128
        AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
        AND     MSI.PLANNER_CODE = P_PLANNER
        --AND     RIE.SUPPLIER LIKE DECODE(P_VENDOR, '109420', 'Celestica%', 'Jabil%')    -- TEMP CODE
        AND     UPPER(REPLACE(SUPPLIER,'.','')) IN (    SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                        FROM    AP_SUPPLIERS
                                                        WHERE   VENDOR_ID = P_VENDOR)
        AND     CIM.PART_NAME LIKE NVL('%'||P_PRODUCT||'%', CIM.PART_NAME)
        AND     CIM.PRODUCT_FAMILY = NVL(P_PRODUCT_FAMILY, CIM.PRODUCT_FAMILY)
        AND     REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13), '') = NVL(P_DEPARTMENT, REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13), ''))

        GROUP BY RIE.COMPONENT_PART,
                CASE WHEN P_VIEW = 'WEEK'  THEN TO_CHAR(RIE.DEMAND_DATE, 'WW')
                     WHEN P_VIEW = 'MONTH' THEN TO_CHAR(RIE.DEMAND_DATE, 'MM')
                     WHEN P_VIEW = 'YEAR'  THEN TO_CHAR(RIE.DEMAND_DATE, 'YYYY')
                     ELSE TO_CHAR(RIE.DEMAND_DATE, 'WW')
                END, 								 
                CASE WHEN P_VIEW = 'WEEK'  THEN RIE.DEMAND_DATE
                     WHEN P_VIEW = 'MONTH' THEN TRUNC(RIE.DEMAND_DATE, 'MONTH')
                     WHEN P_VIEW = 'YEAR'  THEN TRUNC(RIE.DEMAND_DATE, 'YEAR')
                     ELSE RIE.DEMAND_DATE                       
                END,
                TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'YYYY')),
                 CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_TYPE
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_REASON
                END, 
                CASE
                    WHEN (P_LOGIN_TYPE = 'PLNR')    THEN CPA.ADJUSTMENT_COMMENTS
                    WHEN (P_LOGIN_TYPE = 'CM')      THEN CCC.COMMIT_COMMENTS
                END,
                CIM.PART_SITE, CIM.BU, CIM.BUILD_TYPE
                ORDER BY 1, 3;

    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMMIT_VARIANCE > ' || O_ERR_MSG);
    END GET_FORECAST_COMMIT_VARIANCE;

    /*#############################UPDATE_FORECAST_ADJUSTMENTS####################*/

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
    )
    AS
    BEGIN
        SAVEPOINT PLNR_ADJUSTMENT;
        FOR v_index IN XX_FORECAST_ADJ_DETAIL_IN.FIRST .. XX_FORECAST_ADJ_DETAIL_IN.LAST
        LOOP
            INSERT INTO XXKT_COLLAB_PLNR_ADJUSTMENTS 
                    (ADJUSTMENT_ID, PLANNER_ID, SUPPLIER_ID, PRODUCT, 
                    REQ_PLAN_NON_GSA_ADJ, REQ_PLAN_GSA_ADJ, ADJUSTMENT_QUANTITY, ADJUSTMENT_TYPE, ADJUSTMENT_COMMENTS, 
                    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATION_DATE, WEEK_ID, DEMAND_DATE)
            VALUES	(XXKT_PLNR_ADJUSTMENTS_SEQ.NEXTVAL, P_PLANNER, P_VENDOR, XX_FORECAST_ADJ_DETAIL_IN(v_index).V_PRODUCT,
                    XX_FORECAST_ADJ_DETAIL_IN(v_index).V_NON_GSA_ADJUSTMENT , XX_FORECAST_ADJ_DETAIL_IN(v_index).V_GSA_ADJUSTMENT,
                    XX_FORECAST_ADJ_DETAIL_IN(v_index).V_ADJUSTMENT, XX_FORECAST_ADJ_DETAIL_IN(v_index).V_ADJUSTMENT_TYPE,
                    XX_FORECAST_ADJ_DETAIL_IN(v_index).V_ADJUSTMENT_COMMENT, P_PLANNER, SYSDATE, P_PLANNER, SYSDATE, 
                    TO_CHAR(SYSDATE, 'WW'), XX_FORECAST_ADJ_DETAIL_IN(v_index).V_MONDAY);
        END LOOP;
        COMMIT;

        O_SUC_MSG := 'Planner Adjustment details are updated successfully.';
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK TO PLNR_ADJUSTMENT;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMMIT_VARIANCE > ' || O_ERR_MSG);
    END UPDATE_FORECAST_ADJUSTMENTS;

    /*#############################UPDATE_CM_COMMITS##############################*/

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
    )
    AS
    BEGIN
        SAVEPOINT CM_COMMIT;
        FOR v_index IN XX_CM_COMMITS_DETAIL_IN.FIRST .. XX_CM_COMMITS_DETAIL_IN.LAST
        LOOP
            INSERT INTO XXKT_COLLAB_CM_COMMITS 
                    (COMMIT_ID, PLANNER_ID, SUPPLIER_ID, PRODUCT, 
                    NON_GSA_COMMIT_QTY, GSA_COMMIT_QTY, COMMIT_QUANTITY, COMMIT_REASON, COMMIT_COMMENTS, 
                    CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATION_DATE, WEEK_ID, DEMAND_DATE)
            VALUES	(XXKT_CM_COMMITS_SEQ.NEXTVAL, P_PLANNER, P_VENDOR, XX_CM_COMMITS_DETAIL_IN(v_index).V_PRODUCT, 
                    XX_CM_COMMITS_DETAIL_IN(v_index).V_NON_GSA_COMMIT, XX_CM_COMMITS_DETAIL_IN(v_index).V_GSA_COMMIT, 
                    XX_CM_COMMITS_DETAIL_IN(v_index).V_COMMIT, XX_CM_COMMITS_DETAIL_IN(v_index).V_ADJUSTMENT_TYPE, 
                    XX_CM_COMMITS_DETAIL_IN(v_index).V_ADJUSTMENT_COMMENT, P_VENDOR, SYSDATE, P_VENDOR, SYSDATE,
                    TO_CHAR(SYSDATE, 'WW'), XX_CM_COMMITS_DETAIL_IN(v_index).V_MONDAY);
        END LOOP;
        COMMIT;

        O_SUC_MSG := 'Supplier Commitment details are updated successfully.';
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK TO CM_COMMIT;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('UPDATE_CM_COMMITS > ' || O_ERR_MSG);
    END UPDATE_CM_COMMITS;

    /*#############################GET_FORECAST_COMPARISON########################*/

    PROCEDURE GET_FORECAST_COMPARISON(
        P_LOGIN_TYPE					IN VARCHAR2,
        P_LOGIN_VALUE					IN VARCHAR2,
        XX_FORECAST_COMPARISON_OUT  	OUT XX_FORECAST_COMPARISON_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        IF P_LOGIN_TYPE = 'PLNR' THEN
            SELECT	SUP.VENDOR_ID       V_CODE, 
                    SUP.VENDOR_NAME     V_NAME,
                    COUNT(RIE.SUPPLIER) V_NO_OF_EXCEPTIONS,
                    SUM((NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                         NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0)) -
                         (NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                    )                   V_EXCEPTION_QUANTITY
            BULK COLLECT
            INTO 	XX_FORECAST_COMPARISON_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA,
                    AP_SUPPLIERS SUP
            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            AND     MSI.PLANNER_CODE IN (SELECT PLANNER_CODE FROM MTL_PLANNERS WHERE EMPLOYEE_ID = P_LOGIN_VALUE)
            --AND     MSI.PLANNER_CODE = 'EPSG85CM'
            AND     UPPER(VENDOR_NAME) = UPPER(REPLACE(RIE.SUPPLIER,'.',''))
            GROUP BY SUP.VENDOR_ID, SUP.VENDOR_NAME;

        ELSIF P_LOGIN_TYPE = 'CM' THEN
            SELECT	MSI.PLANNER_CODE    V_CODE, 
                    MP.DESCRIPTION      V_NAME,
                    COUNT(RIE.SUPPLIER) V_NO_OF_EXCEPTIONS,
                    SUM((NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                         NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0)) -
                         (NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                    )                   V_EXCEPTION_QUANTITY
            BULK COLLECT
            INTO 	XX_FORECAST_COMPARISON_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA,
                    MTL_PLANNERS MP
            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            AND     MSI.PLANNER_CODE = MP.PLANNER_CODE
            --AND     RIE.SUPPLIER LIKE DECODE(P_LOGIN_VALUE, '109420', 'Celestica%', 'Jabil%')
            AND     UPPER(REPLACE(RIE.SUPPLIER,'.','')) IN (SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                            FROM    AP_SUPPLIERS
                                                            WHERE   VENDOR_ID = P_LOGIN_VALUE)
            GROUP BY MSI.PLANNER_CODE, MP.DESCRIPTION;

        END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMPARISON > ' || O_ERR_MSG);
    END GET_FORECAST_COMPARISON;

    /*#############################GET_FORECAST_VS_COMMIT#########################*/

    PROCEDURE GET_FORECAST_VS_COMMIT(
        P_LOGIN_TYPE					IN VARCHAR2,
        P_LOGIN_VALUE					IN VARCHAR2,
        XX_FORECAST_VS_COMMIT_OUT		OUT XX_FORECAST_VS_COMMIT_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        IF P_LOGIN_TYPE = 'PLNR' THEN
            SELECT	((NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                      NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0))
                    )                               V_TOTAL_FORECAST,
                    ((NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                    )                               V_TOTAL_COMMIT
            BULK COLLECT
            INTO 	XX_FORECAST_VS_COMMIT_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA

            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            AND     MSI.PLANNER_CODE IN (SELECT PLANNER_CODE FROM MTL_PLANNERS WHERE EMPLOYEE_ID = P_LOGIN_VALUE);

        ELSIF P_LOGIN_TYPE = 'CM' THEN
           SELECT	(NVL(RIE.REQ_PLAN_NON_GSA, 0) + NVL(RIE.REQ_PLAN_GSA, 0) + NVL(RIE.REQ_PLAN_FORECAST, 0) +
                     NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0) + NVL(CPA.REQ_PLAN_GSA_ADJ, 0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0))
                                                    V_TOTAL_FORECAST,
                    (NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))
                                                    V_TOTAL_COMMIT
            BULK    COLLECT
            INTO 	XX_FORECAST_VS_COMMIT_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA

            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            --AND     RIE.SUPPLIER LIKE DECODE(P_LOGIN_VALUE, '109420', 'Celestica%', 'Jabil%');
            AND     UPPER(REPLACE(RIE.SUPPLIER,'.','')) IN (SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                            FROM    AP_SUPPLIERS
                                                            WHERE   VENDOR_ID = P_LOGIN_VALUE);
        END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_VS_COMMIT > ' || O_ERR_MSG);
    END GET_FORECAST_VS_COMMIT;

    /*#############################GET_FORECAST_COMMIT_RECEIVE####################*/

    PROCEDURE GET_FORECAST_COMMIT_RECEIVE(
        P_LOGIN_TYPE                    IN  VARCHAR2,
        P_LOGIN_VALUE	                IN  VARCHAR2,
        XX_FCR_OUT  	                OUT XX_FORECAST_COMMIT_RECEIVE_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        IF P_LOGIN_TYPE = 'PLNR' THEN
            SELECT  'WEEK'              V_VIEW,
                    RIE.DEMAND_DATE     V_FORECAST_DATE,
                    SUM(TO_NUMBER(NVL(RIE.REQ_PLAN_NON_GSA,0) + NVL(RIE.REQ_PLAN_GSA,0) + NVL(RIE.REQ_PLAN_FORECAST,0) +
                    NVL(CPA.REQ_PLAN_NON_GSA_ADJ,0) + NVL(CPA.REQ_PLAN_GSA_ADJ,0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0))) 
                                        V_TOTAL_FORECAST,
                    SUM(TO_NUMBER(NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))) 
                                        V_TOTAL_COMMIT,
                    SUM(NVL(0, 0))      V_TOTAL_RECEIVED
            BULK    COLLECT
            INTO    XX_FCR_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA

            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            AND     MSI.PLANNER_CODE IN (SELECT PLANNER_CODE FROM MTL_PLANNERS WHERE EMPLOYEE_ID = P_LOGIN_VALUE)
            --AND     MSI.PLANNER_CODE = 'EPSG85CM'
            GROUP BY RIE.DEMAND_DATE
            ORDER BY RIE.DEMAND_DATE
            FETCH FIRST 5 ROWS ONLY;

        ELSIF P_LOGIN_TYPE = 'CM' THEN
            SELECT  'WEEK'                          V_VIEW, 
                    RIE.DEMAND_DATE                 V_FORECAST_DATE,
                    SUM(TO_NUMBER(NVL(RIE.REQ_PLAN_NON_GSA,0) + NVL(RIE.REQ_PLAN_GSA,0) + NVL(RIE.REQ_PLAN_FORECAST,0) +
                    NVL(CPA.REQ_PLAN_NON_GSA_ADJ,0) + NVL(CPA.REQ_PLAN_GSA_ADJ,0) + NVL(CPA.ADJUSTMENT_QUANTITY, 0))) 
                                                    V_TOTAL_FORECAST,
                    SUM(TO_NUMBER(NVL(CCC.NON_GSA_COMMIT_QTY, 0) + NVL(CCC.GSA_COMMIT_QTY, 0) + NVL(CCC.COMMIT_QUANTITY, 0))) 
                                                    V_TOTAL_COMMIT,
                    SUM(NVL(0, 0))                  V_TOTAL_RECEIVED
            BULK    COLLECT
            INTO    XX_FCR_OUT
            FROM    XXKT_RR_IRP_EXTRACT RIE, 
                    XXKT_COLLAB_ITEM_MASTER CIM, 
                    MTL_SYSTEM_ITEMS_B MSI,
                    XXKT_COLLAB_CM_COMMITS CCC, 
                    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA

            WHERE   MSI.SEGMENT1 = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CIM.PART_NAME
            AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
            AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
            AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                            WHERE   CCC1.PRODUCT = CCC.PRODUCT
                                                            AND     CCC1.WEEK_ID = CCC.WEEK_ID
                                                            AND     CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
            AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
            AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
            AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
            AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (  SELECT  NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                            FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                            WHERE   CPA1.PRODUCT = CPA.PRODUCT
                                                            AND     CPA1.WEEK_ID = CPA.WEEK_ID
                                                            AND     CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
            AND     MSI.ORGANIZATION_ID = 128
            AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
            --AND     RIE.SUPPLIER LIKE DECODE(P_LOGIN_VALUE, '109420', 'Celestica%', 'Jabil%')
            AND     UPPER(REPLACE(RIE.SUPPLIER,'.','')) IN (SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                            FROM    AP_SUPPLIERS
                                                            WHERE   VENDOR_ID = P_LOGIN_VALUE)
            GROUP BY RIE.DEMAND_DATE
            ORDER BY RIE.DEMAND_DATE
            FETCH FIRST 5 ROWS ONLY;
        END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMMIT_RECEIVE > ' || O_ERR_MSG);
    END GET_FORECAST_COMMIT_RECEIVE;

    /*#############################GET_OPEN_TASK_NOTIFICATION#####################*/

    PROCEDURE GET_OPEN_TASK_NOTIFICATION(
        P_LOGIN_TYPE                    IN  VARCHAR2,
        P_LOGIN_VALUE	                IN  VARCHAR2,
        XX_OPEN_TASK_OUT  	            OUT XX_OPEN_TASK_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        IF P_LOGIN_TYPE = 'PLNR' THEN

            SELECT TASK_REQUEST_ID, TASK_APPROVAL_ID, PRODUCT, FORECAST_DATE, VARIANCES, 
                   TASK_STATUS, TASK_FROM, TASK_TO, TASK_SUBJECT, TASK_MESSAGE
              BULK COLLECT
              INTO XX_OPEN_TASK_OUT
              FROM XXKT_COLLAB_TASK_DETAIL
             WHERE 1 = 1
               AND CREATED_BY = P_LOGIN_VALUE
               AND UPPER(TASK_STATUS) <> 'CLOSE'
               --AND TO_CHAR(CREATION_DATE, 'WW') = TO_CHAR(SYSDATE, 'WW')
         ORDER BY TASK_REQUEST_ID;

        ELSIF P_LOGIN_TYPE = 'CM' THEN

            SELECT TASK_REQUEST_ID, TASK_APPROVAL_ID, PRODUCT, FORECAST_DATE, VARIANCES, 
                   TASK_STATUS, TASK_FROM, TASK_TO, TASK_SUBJECT, TASK_MESSAGE
              BULK COLLECT
              INTO XX_OPEN_TASK_OUT
              FROM XXKT_COLLAB_TASK_DETAIL CTD, AP_SUPPLIERS SUP
             WHERE 1 = 1
               AND CTD.TASK_TO = SUP.VENDOR_NAME
               AND SUP.VENDOR_ID = P_LOGIN_VALUE
               AND UPPER(TASK_STATUS) <> 'CLOSE'
               --AND TO_CHAR(CREATION_DATE, 'WW') = TO_CHAR(SYSDATE, 'WW')
          ORDER BY TASK_REQUEST_ID;

        END IF;
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_COMMIT_RECEIVE > ' || O_ERR_MSG);
    END GET_OPEN_TASK_NOTIFICATION;

    /*#############################GET_OPEN_TASK_NOTIFICATION#####################*/

    PROCEDURE GET_OPEN_POS(
        P_LOGIN_TYPE                    IN  VARCHAR2,
        P_LOGIN_VALUE	                IN  VARCHAR2,
        XX_OPEN_POS_OUT                 OUT XX_OPEN_POS_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        SELECT TO_CHAR(VENDOR_ID)       V_CODE, 
               VENDOR_NAME              V_NAME,
               1                        V_NO_OF_OPEN_POS,
               10                       V_OPEN_POS_QUANTITY
          BULK COLLECT
          INTO XX_OPEN_POS_OUT
          FROM AP_SUPPLIERS 
         WHERE VENDOR_ID IN (109420, 28306, 25917, 18025, 77523, 1388845);
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_OPEN_POS > ' || O_ERR_MSG);
    END GET_OPEN_POS;

    /*#############################GET_DASHBOARD_INFORMATION######################*/

    PROCEDURE GET_DASHBOARD_INFORMATION(
        P_LOGIN_TYPE    				IN 	VARCHAR2,
        P_LOGIN_VALUE					IN 	VARCHAR2,
        XX_FORECAST_COMPARISON_OUT      OUT XX_FORECAST_COMPARISON_TBL,
        XX_FORECAST_VS_COMMIT_OUT		OUT XX_FORECAST_VS_COMMIT_TBL,
        XX_FCR_OUT	            	    OUT XX_FORECAST_COMMIT_RECEIVE_TBL,
        XX_OPEN_TASK_OUT                OUT XX_OPEN_TASK_TBL,
        XX_OPEN_POS_OUT                 OUT XX_OPEN_POS_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        GET_FORECAST_COMPARISON		(P_LOGIN_TYPE, P_LOGIN_VALUE, XX_FORECAST_COMPARISON_OUT, O_ERR_MSG);
        GET_FORECAST_VS_COMMIT		(P_LOGIN_TYPE, P_LOGIN_VALUE, XX_FORECAST_VS_COMMIT_OUT, O_ERR_MSG);
        GET_FORECAST_COMMIT_RECEIVE	(P_LOGIN_TYPE, P_LOGIN_VALUE, XX_FCR_OUT, O_ERR_MSG);
        GET_OPEN_TASK_NOTIFICATION  (P_LOGIN_TYPE, P_LOGIN_VALUE, XX_OPEN_TASK_OUT, O_ERR_MSG);
        GET_OPEN_POS                (P_LOGIN_TYPE, P_LOGIN_VALUE, XX_OPEN_POS_OUT, O_ERR_MSG);
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_DASHBOARD_INFORMATION > ' || O_ERR_MSG);
    END GET_DASHBOARD_INFORMATION;

    /*#############################LOAD_SUBMITTED_REQUESTS########################*/

    PROCEDURE LOAD_SUBMITTED_REQUESTS(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_SUBMITTED_REQUEST_OUT	    OUT	XX_UNPLANNED_REQUEST_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        SELECT 	PRODUCT_FAMILY V_PRODUCT_FAMILY, PRODUCT_LINE V_PRODUCT_LINE, PRODUCT V_PRODUCT, 
                CREATION_DATE V_REQUEST_DATE, REQUEST_QUANTITY V_REQUEST_QUANTITY, REQUEST_TYPE V_REQUEST_TYPE, 
                REQUEST_COMMENTS V_REQUEST_COMMENTS, APPROVER_ID V_APPROVER
        BULK COLLECT
        INTO 	XX_SUBMITTED_REQUEST_OUT
        FROM 	XXKT_UNPLANNED_REQUESTS
        WHERE 	1 = 1;
        --AND 	PLANNER_ID 	= P_LOGIN_TYPE
        --AND 	WEEK_ID		= TO_CHAR(SYSDATE, 'WW');
    EXCEPTION 
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('LOAD_SUBMITTED_REQUESTS > ' || O_ERR_MSG);
    END LOAD_SUBMITTED_REQUESTS;

    /*#############################SAVE_UNPLANNED_ADJUSTMENT######################*/

    PROCEDURE SAVE_UNPLANNED_REQUEST(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_NEW_REQUEST_IN	            IN	XX_UNPLANNED_REQUEST_TBL,
        XX_REMOVE_REQUEST_IN	        IN	XX_UNPLANNED_REQUEST_TBL,
        O_SUC_MSG					    OUT VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
        l_ITEMTYPE               VARCHAR2 (30)   := 'XXCOLLAB';
        l_ITEMKEY                VARCHAR2 (300);
        V_WF_REQUESTOR           VARCHAR2 (200);
        v_APPROVAL_ID            VARCHAR2 (50);
        cursor c_approval is
            select * from XXKT_UNPLANNED_REQUESTS 
            where  (approval_status is null or approval_status = 'NEW');
    BEGIN
        SAVEPOINT UNPLANNED_REQUEST;
        IF XX_NEW_REQUEST_IN IS NOT NULL THEN
            FOR v_index IN XX_NEW_REQUEST_IN.FIRST .. XX_NEW_REQUEST_IN.LAST
            LOOP
                IF  XX_NEW_REQUEST_IN(v_index).V_PRODUCT_FAMILY     IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_PRODUCT_LINE       IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_PRODUCT            IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_REQUEST_QUANTITY   IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_REQUEST_TYPE       IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_REQUEST_COMMENTS   IS NOT NULL AND
                    XX_NEW_REQUEST_IN(v_index).V_APPROVER           IS NOT NULL THEN

                        INSERT INTO XXKT_UNPLANNED_REQUESTS(
                                REQUEST_ID, PLANNER_ID, SUPPLIER_ID, 
                                PRODUCT_FAMILY, PRODUCT_LINE, PRODUCT, 
                                REQUEST_QUANTITY, REQUEST_TYPE, REQUEST_COMMENTS, 
                                CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATION_DATE, 
                                APPROVAL_STATUS, APPROVAL_WORKFLOW_ID, APPROVER_ID, APPROVED_DATE, WEEK_ID  
                        )VALUES(
                                XXKT_UNPLANNED_REQUESTS_SEQ.NEXTVAL, P_LOGIN_VALUE, '', 
                                XX_NEW_REQUEST_IN(v_index).V_PRODUCT_FAMILY, XX_NEW_REQUEST_IN(v_index).V_PRODUCT_LINE, XX_NEW_REQUEST_IN(v_index).V_PRODUCT,
                                XX_NEW_REQUEST_IN(v_index).V_REQUEST_QUANTITY, XX_NEW_REQUEST_IN(v_index).V_REQUEST_TYPE, XX_NEW_REQUEST_IN(v_index).V_REQUEST_COMMENTS, 
                                P_LOGIN_VALUE, SYSDATE, P_LOGIN_VALUE, SYSDATE,
                                '', '', XX_NEW_REQUEST_IN(v_index).V_APPROVER, SYSDATE, TO_CHAR(SYSDATE, 'WW')
                        );
                END IF;
            END LOOP;	
        END IF;

        IF XX_REMOVE_REQUEST_IN IS NOT NULL THEN
            FOR v_index IN XX_REMOVE_REQUEST_IN.FIRST .. XX_REMOVE_REQUEST_IN.LAST
            LOOP
                IF  XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT_FAMILY      IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT_LINE        IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT             IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_QUANTITY    IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_TYPE        IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_DATE        IS NOT NULL AND
                    XX_REMOVE_REQUEST_IN(v_index).V_APPROVER            IS NOT NULL THEN

                        DELETE FROM XXKT_UNPLANNED_REQUESTS
                        WHERE   PLANNER_ID      = P_LOGIN_VALUE
                        AND     CREATED_BY      = P_LOGIN_VALUE
                        AND     PRODUCT_FAMILY  = XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT_FAMILY
                        AND     PRODUCT_LINE    = XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT_LINE
                        AND     PRODUCT         = XX_REMOVE_REQUEST_IN(v_index).V_PRODUCT
                        AND     REQUEST_QUANTITY= XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_QUANTITY
                        AND     REQUEST_TYPE    = XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_TYPE;
                        --AND     TO_CHAR(CREATION_DATE, 'YYYY-MM-DD') = XX_REMOVE_REQUEST_IN(v_index).V_REQUEST_DATE;	
                END IF;
            END LOOP;
        END IF;
        COMMIT;

        O_SUC_MSG := 'Unpalnned requests are saved/updated successfully';

        begin
        FOR i IN c_approval LOOP
         BEGIN
        -- Initiate Request Approval.
          XXKT_COLLAB_WF_PROCESS.XX_INITIATE_REQ_APPROVAL (i.request_id,V_APPROVAL_ID);
          -- update approval workflow status in requests table.
            UPDATE   XXKT_UNPLANNED_REQUESTS
            SET   approval_status = 'In Process',
            APPROVAL_WORKFLOW_ID = V_APPROVAL_ID
            where  request_id = i.request_id;   
            COMMIT;       
         exception when others then
          O_ERR_MSG := O_ERR_MSG || SQLCODE ||': ' || SQLERRM;
          UPDATE   XXKT_UNPLANNED_REQUESTS
            SET   approval_status = 'ERROR',
            APPROVAL_WORKFLOW_ID = V_APPROVAL_ID
            where  request_id = i.request_id;   
            COMMIT; 
        end;
             END LOOP;                    
        exception when others then
          O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
        end;
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK TO UNPLANNED_REQUEST;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('SAVE_UNPLANNED_REQUEST > ' || O_ERR_MSG);
    END SAVE_UNPLANNED_REQUEST;

    /*#######################CREATE_UPDATE_TASK##################*/

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
    )
    AS
        L_REQUEST_ID                    NUMBER;
        L_MESSAGE                       XXKT_COLLAB_TASK_DETAIL.TASK_MESSAGE%TYPE;
    BEGIN
        IF P_ACTION = 'CREATE' THEN
            --XXKT_COLLAB_WF_PROCESS.XX_INITIATE_REQ_APPROVAL (L_REQUEST_ID, O_APPROVAL_ID);

            L_REQUEST_ID := XXKT_COLLAB_TASK_SEQ.NEXTVAL;
            O_APPROVAL_ID := L_REQUEST_ID;

            L_MESSAGE := '<U>' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || ' [' || P_FROM || ']</U><BR/>' || P_MESSAGE || '<BR/>';

            INSERT INTO XXKT_COLLAB_TASK_DETAIL (TASK_REQUEST_ID, TASK_APPROVAL_ID, 
                   PLANNER, TASK_FROM, SUPPLIER, TASK_TO,
                   PRODUCT, FORECAST_DATE, VARIANCES, TASK_STATUS, TASK_SUBJECT, TASK_MESSAGE, 
                   CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATION_DATE)
            VALUES (L_REQUEST_ID, O_APPROVAL_ID, 
                   P_PLANNER, P_FROM, P_SUPPLIER, P_TO, 
                   P_PRODUCT, P_FORECAST_DATE, P_VARIANCE, P_STATUS, P_SUBJECT, L_MESSAGE,
                   P_LOGIN_VALUE, SYSDATE, P_LOGIN_VALUE, SYSDATE);

            O_SUC_MSG := 'Task is created with id: <B>' || O_APPROVAL_ID || '</B>';
        ELSIF P_ACTION = 'UPDATE' THEN
        
            IF P_LOGIN_TYPE = 'PLNR' THEN
                L_MESSAGE := '<BR/><U>' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || ' [' || P_FROM || ']</U><BR/>' || P_MESSAGE || '<BR/>';
            ELSIF P_LOGIN_TYPE = 'CM' THEN
                L_MESSAGE := '<BR/><U>' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS') || ' [' || P_TO || ']</U><BR/>' || P_MESSAGE || '<BR/>';
            END IF;
            
            UPDATE XXKT_COLLAB_TASK_DETAIL 
               SET TASK_STATUS = P_STATUS, 
                   TASK_MESSAGE = TASK_MESSAGE || L_MESSAGE, 
                   UPDATED_BY = P_LOGIN_VALUE, 
                   UPDATION_DATE = SYSDATE
             WHERE TASK_REQUEST_ID = P_REQUEST_ID;

             O_SUC_MSG := 'Task id: <B>' || P_REQUEST_ID ||'</B> is updated as <B>' || P_STATUS || '</B> status.';
        END IF;

        COMMIT;
    EXCEPTION 
        WHEN OTHERS THEN
            ROLLBACK;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('CREATE_UPDATE_TASK > ' || O_ERR_MSG);
    END CREATE_UPDATE_TASK;

    /*#######################GET_USER_PREFERENCE##############################*/

    PROCEDURE GET_USER_PREFERENCES(
        P_USER_NAME                     IN  XXKT_COLLAB_USER_PREFERENCE.USER_NAME%TYPE,
        P_USER_ID                       IN  XXKT_COLLAB_USER_PREFERENCE.USER_ID%TYPE,
        XX_USER_PREFERENCE_OUT          OUT XX_USER_PREFERENCE_TBL,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
    BEGIN
        SELECT USER_ID, USER_NAME, PREFERENCE_NAME, PREFERENCE_VALUE
          BULK COLLECT
          INTO XX_USER_PREFERENCE_OUT
          FROM XXKT_COLLAB_USER_PREFERENCE
         WHERE USER_ID = P_USER_ID;
    EXCEPTION
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_USER_PREFERENCES > ' || O_ERR_MSG);
    END GET_USER_PREFERENCES;

    /*#######################SET_USER_PREFERENCES#############################*/

   PROCEDURE UPDATE_USER_PREFERENCES(
        P_LOGIN_TYPE    		        IN 	VARCHAR2,
        P_LOGIN_VALUE			        IN 	VARCHAR2,
        XX_USER_PREFERENCE_IN          	IN  XX_USER_PREFERENCE_TBL,
        O_SUC_MSG                       OUT	VARCHAR2,
        O_ERR_MSG                       OUT VARCHAR2
    )
    AS
        L_CLEANED                       VARCHAR2(5) := 'N';
    BEGIN
        FOR v_index IN XX_USER_PREFERENCE_IN.FIRST .. XX_USER_PREFERENCE_IN.LAST
        LOOP
            IF L_CLEANED = 'N' THEN
                DELETE FROM XXKT_COLLAB_USER_PREFERENCE
                 WHERE USER_ID = XX_USER_PREFERENCE_IN(v_index).V_USER_ID;
                L_CLEANED := 'Y';
            END IF;

            INSERT INTO XXKT_COLLAB_USER_PREFERENCE(USER_ID, USER_NAME, PREFERENCE_NAME, PREFERENCE_VALUE)
            VALUES (XX_USER_PREFERENCE_IN(v_index).V_USER_ID, XX_USER_PREFERENCE_IN(v_index).V_USER_NAME, 
                    XX_USER_PREFERENCE_IN(v_index).V_PREFERENCE_NAME, XX_USER_PREFERENCE_IN(v_index).V_PREFERENCE_VALUE);
        END LOOP;

        O_SUC_MSG := 'User Preferences are saved';
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('UPDATE_USER_PREFERENCES > ' || O_ERR_MSG);
    END UPDATE_USER_PREFERENCES;

    /*#######################AD_HOC_FORECAST##################################*/

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
    )
    AS
        L_WEEK_ID                       NUMBER(5);
        L_NO_OF_REC                     NUMBER(5);
        L_VENDER_NAME                   VARCHAR2(100);
    BEGIN
        --WHETHER PROVIDED PRODUCT CODE IS PRESENT IN KEYSIGHT
        SELECT COUNT(PART_NAME)
          INTO L_NO_OF_REC
          FROM XXKT_COLLAB_ITEM_MASTER
         WHERE PART_NAME = P_PRODUCT;

        IF L_NO_OF_REC <= 0 THEN
            O_SUC_MSG := 'Invalid Product';
        ELSE
            --WHETHER TABLE ALREADY HAS FORECAST FOR THAT WEEK
            SELECT TO_CHAR(P_FORECAST_DATE, 'WW'), COUNT(DEMAND_DATE) 
              INTO L_WEEK_ID, L_NO_OF_REC
              FROM XXKT_RR_IRP_EXTRACT
             WHERE COMPONENT_PART = P_PRODUCT
               AND TO_NUMBER(TO_CHAR(DEMAND_DATE, 'WW')) = TO_NUMBER(TO_CHAR(P_FORECAST_DATE, 'WW'));

            IF L_NO_OF_REC > 0 THEN
                O_SUC_MSG := 'Forecast request is already present. Please update your adjutment quantity for weekid: <B>' || L_WEEK_ID || '</B>';
            ELSE            
                --FETCH THE VENDOR NAME USING VENDOR CODE
                SELECT VENDOR_NAME
                  INTO L_VENDER_NAME
                  FROM AP_SUPPLIERS
                 WHERE VENDOR_ID = P_VENDOR;

                --CREATE BLANK ENTRY FOR A MISSED FORECAST DATE
                INSERT INTO XXKT_RR_IRP_EXTRACT (WEEK_ID, COMPONENT_PART, DEMAND_DATE, 
                        REQ_PLAN_NON_GSA, REQ_PLAN_GSA, REQ_PLAN_FORECAST, REQ_PLAN_BUFFER, REQ_PLAN_BUFFER_OPT_ADJ, 
                        PRODUCT_FAMILY, SUPPLIER, REMARKS)
                VALUES (TO_CHAR(SYSDATE, 'WW'), P_PRODUCT, P_FORECAST_DATE, 
                        0, 0, 0, 0, 0, P_PRODUCT_FAMILY, L_VENDER_NAME, P_ADJ_COMMENT);

                --ADD REQUESTED QANTITY IN PLANNER ADJUSTMENT TABLE AS ADJUSTMENT
                INSERT INTO XXKT_COLLAB_PLNR_ADJUSTMENTS (ADJUSTMENT_ID, PLANNER_ID, SUPPLIER_ID, PRODUCT, 
                        REQ_PLAN_NON_GSA_ADJ, REQ_PLAN_GSA_ADJ, ADJUSTMENT_QUANTITY, ADJUSTMENT_TYPE, ADJUSTMENT_COMMENTS, 
                        CREATED_BY, CREATION_DATE, UPDATED_BY, UPDATION_DATE, WEEK_ID, DEMAND_DATE)
                VALUES (XXKT_PLNR_ADJUSTMENTS_SEQ.NEXTVAL, P_PLANNER, P_VENDOR, P_PRODUCT,
                        P_NON_GSA_ADJ_QTY, P_GSA_ADJ_QTY, P_FORECAST_ADJ_QTY, P_ADJ_TYPE, P_ADJ_COMMENT, 
                        P_PLANNER, SYSDATE, P_PLANNER, SYSDATE, TO_CHAR(SYSDATE, 'WW'), P_FORECAST_DATE);

                COMMIT;
                O_SUC_MSG := 'Ad Hoc Forecast request for weekid: <B>'|| L_WEEK_ID || '</B> has been submitted successfully.';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('AD_HOC_FORECAST > ' || O_ERR_MSG);
    END AD_HOC_FORECAST;

    /*#######################GET_FORECAST_INFO_COMPARISON##############################*/

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
    )
    AS

    BEGIN
        --LAST WEEK
        SELECT  RIE.COMPONENT_PART                      V_PRODUCT, 
                TO_CHAR(RIE.DEMAND_DATE-7, 'WW')        V_WEEK_ID, 
                TRUNC(RIE.DEMAND_DATE-7, 'IW')          V_FORECAST_DATE, 
                SUM(NVL(RIE.REQ_PLAN_NON_GSA, 0))       V_NON_GSA_REQ, 
                SUM(NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0))   V_NON_GSA_ADJ, 
                SUM(NVL(CCC.NON_GSA_COMMIT_QTY, 0))     V_NON_GSA_COMMIT, 
                SUM(NVL(RIE.REQ_PLAN_GSA, 0))           V_GSA_REQ, 
                SUM(NVL(CPA.REQ_PLAN_GSA_ADJ, 0))       V_GSA_ADJ, 
                SUM(NVL(CCC.GSA_COMMIT_QTY, 0))         V_GSA_COMMIT, 
                SUM(NVL(RIE.REQ_PLAN_FORECAST, 0))      V_FORECAST_REQ, 
                SUM(NVL(CPA.ADJUSTMENT_QUANTITY, 0))    V_FORECAST_ADJ, 
                SUM(NVL(CCC.COMMIT_QUANTITY, 0))        V_FORECAST_COMMIT

        BULK    COLLECT
        INTO    XX_FC_LAST_WEEK_OUT

        FROM    XXKT_RR_IRP_EXTRACT RIE, 
                XXKT_COLLAB_ITEM_MASTER CIM, 
                MTL_SYSTEM_ITEMS_B MSI, 
                XXKT_COLLAB_CM_COMMITS CCC, 
                XXKT_COLLAB_PLNR_ADJUSTMENTS CPA
        WHERE   MSI.SEGMENT1 = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
        AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
        AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
        AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                        WHERE 	CCC1.PRODUCT = CCC.PRODUCT
                                                        AND 	CCC1.WEEK_ID = CCC.WEEK_ID
                                                        AND 	CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
        AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
        AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
        AND     RIE.WEEK_ID = TO_CHAR(SYSDATE, 'WW')
        AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
        AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                        WHERE 	CPA1.PRODUCT = CPA.PRODUCT
                                                        AND 	CPA1.WEEK_ID = CPA.WEEK_ID
                                                        AND 	CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
        AND     MSI.ORGANIZATION_ID = 128
        AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
        AND		(TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'WW'))) = (TO_NUMBER(TO_CHAR(SYSDATE, 'WW')))
        AND     TO_CHAR(RIE.DEMAND_DATE-7, 'YYYY') = 2020
        --AND     TO_CHAR(RIE.DEMAND_DATE-7, 'YYYY') = P_WEEK1YR
        --AND     TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE-7, 'WW')) = P_WEEK1WK
        AND     MSI.PLANNER_CODE = P_PLANNER
        AND     UPPER(REPLACE(SUPPLIER,'.','')) IN (    SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                        FROM    AP_SUPPLIERS
                                                        WHERE   VENDOR_ID = P_VENDOR)
        AND     CIM.PART_NAME LIKE NVL('%'||P_PRODUCT||'%', CIM.PART_NAME)
        --AND     XXXX = NVL(P_PRODUCT_LINE, XXX)
        AND     CIM.PRODUCT_FAMILY = NVL(P_PRODUCT_FAMILY, CIM.PRODUCT_FAMILY)
        AND     REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),'') = NVL(P_DEPARTMENT, REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),''))
        GROUP BY RIE.COMPONENT_PART, TO_CHAR(RIE.DEMAND_DATE-7, 'WW'), TRUNC(RIE.DEMAND_DATE-7, 'IW')
        ORDER BY RIE.COMPONENT_PART, TRUNC(RIE.DEMAND_DATE-7, 'IW');

        --CURRENT WEEK
        SELECT  RIE.COMPONENT_PART                      V_PRODUCT, 
                TO_CHAR(RIE.DEMAND_DATE, 'WW')          V_WEEK_ID, 
                TRUNC(RIE.DEMAND_DATE, 'IW')            V_FORECAST_DATE, 
                SUM(NVL(RIE.REQ_PLAN_NON_GSA, 0))       V_NON_GSA_REQ, 
                SUM(NVL(CPA.REQ_PLAN_NON_GSA_ADJ, 0))   V_NON_GSA_ADJ, 
                SUM(NVL(CCC.NON_GSA_COMMIT_QTY, 0))     V_NON_GSA_COMMIT, 
                SUM(NVL(RIE.REQ_PLAN_GSA, 0))           V_GSA_REQ, 
                SUM(NVL(CPA.REQ_PLAN_GSA_ADJ, 0))       V_GSA_ADJ, 
                SUM(NVL(CCC.GSA_COMMIT_QTY, 0))         V_GSA_COMMIT, 
                SUM(NVL(RIE.REQ_PLAN_FORECAST, 0))      V_FORECAST_REQ, 
                SUM(NVL(CPA.ADJUSTMENT_QUANTITY, 0))    V_FORECAST_ADJ, 
                SUM(NVL(CCC.COMMIT_QUANTITY, 0))        V_FORECAST_COMMIT

        BULK    COLLECT
        INTO    XX_FC_CURR_WEEK_OUT

        FROM    XXKT_RR_IRP_EXTRACT RIE, 
                XXKT_COLLAB_ITEM_MASTER CIM, 
                MTL_SYSTEM_ITEMS_B MSI, 
                XXKT_COLLAB_CM_COMMITS CCC, 
                XXKT_COLLAB_PLNR_ADJUSTMENTS CPA
        WHERE   MSI.SEGMENT1 = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CIM.PART_NAME
        AND     RIE.COMPONENT_PART = CCC.PRODUCT (+)
        AND     RIE.WEEK_ID = CCC.WEEK_ID (+)
        AND     RIE.DEMAND_DATE = CCC.DEMAND_DATE (+)
        AND     NVL(CCC.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CCC1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_CM_COMMITS CCC1 
                                                        WHERE 	CCC1.PRODUCT = CCC.PRODUCT
                                                        AND 	CCC1.WEEK_ID = CCC.WEEK_ID
                                                        AND 	CCC1.DEMAND_DATE = CCC.DEMAND_DATE)
        AND     RIE.COMPONENT_PART = CPA.PRODUCT (+)
        AND     RIE.WEEK_ID = CPA.WEEK_ID (+)
        AND     RIE.WEEK_ID = TO_CHAR(SYSDATE, 'WW')
        AND     RIE.DEMAND_DATE = CPA.DEMAND_DATE (+)
        AND     NVL(CPA.CREATION_DATE, SYSDATE+10) = (	SELECT 	NVL(MAX(CPA1.CREATION_DATE), SYSDATE+10) 
                                                        FROM    XXKT_COLLAB_PLNR_ADJUSTMENTS CPA1 
                                                        WHERE 	CPA1.PRODUCT = CPA.PRODUCT
                                                        AND 	CPA1.WEEK_ID = CPA.WEEK_ID
                                                        AND 	CPA1.DEMAND_DATE = CPA.DEMAND_DATE)
        AND     MSI.ORGANIZATION_ID = 128
        AND     (MSI.PLANNER_CODE LIKE '%CM' OR  MSI.PLANNER_CODE LIKE '%B2B')
        AND		(TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'WW'))) = (TO_NUMBER(TO_CHAR(SYSDATE, 'WW')))
        AND     TO_CHAR(RIE.DEMAND_DATE, 'YYYY') = 2020
        --AND     TO_CHAR(RIE.DEMAND_DATE-7, 'YYYY') = P_WEEK2YR
        --AND     TO_NUMBER(TO_CHAR(RIE.DEMAND_DATE, 'WW')) = P_WEEK2WK
        AND     MSI.PLANNER_CODE = P_PLANNER
        AND     UPPER(REPLACE(SUPPLIER,'.','')) IN (    SELECT  DISTINCT UPPER(VENDOR_NAME)
                                                        FROM    AP_SUPPLIERS
                                                        WHERE   VENDOR_ID = P_VENDOR)
        AND     CIM.PART_NAME LIKE NVL('%'||P_PRODUCT||'%', CIM.PART_NAME)
        --AND     XXXX = NVL(P_PRODUCT_LINE, XXX)
        AND     CIM.PRODUCT_FAMILY = NVL(P_PRODUCT_FAMILY, CIM.PRODUCT_FAMILY)
        AND     REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),'') = NVL(P_DEPARTMENT, REPLACE(REPLACE(CIM.DEPT,CHR(10), ''), CHR(13),''))
        GROUP BY RIE.COMPONENT_PART, TO_CHAR(RIE.DEMAND_DATE, 'WW'), TRUNC(RIE.DEMAND_DATE, 'IW')
        ORDER BY RIE.COMPONENT_PART, TRUNC(RIE.DEMAND_DATE, 'IW');

    EXCEPTION
        WHEN OTHERS THEN
            O_ERR_MSG := SQLCODE ||': ' || SQLERRM;
            DBMS_OUTPUT.PUT_LINE('GET_FORECAST_INFO_COMPARISON > ' || O_ERR_MSG);
    END GET_FORECAST_INFO_COMPARISON;
    /*########################################################################*/

END XXKT_COLLAB_PORTAL_PKG;
