
CREATE COLUMN TABLE "MUNOZSAM"."ZVBAK" (
"VBELN" NVARCHAR(10),
"ERDAT" NVARCHAR(8),
"VKORG" NVARCHAR(4),
"NETWR" DECIMAL(13,2)
)

TRUNCATE TABLE "MUNOZSAM"."ZVBAK";
SELECT * FROM "MUNOZSAM"."ZVBAK";


DO
BEGIN

/*DDL Ini--------------------------------------------------------------------------------*/
DECLARE VAR_OUT_MESSAGE NVARCHAR(100) := 'Undefined Message';
DECLARE VAR_RESULT DECIMAL(13,2) := 0;
/*DDL Fin--------------------------------------------------------------------------------*/

/*TCL Ini--------------------------------------------------------------------------------*/
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
ROLLBACK;
VAR_OUT_MESSAGE := ::SQL_ERROR_CODE ||': ' || ::SQL_ERROR_MESSAGE;
SELECT :VAR_OUT_MESSAGE AS "OUT_MESSAGE" FROM "DUMMY";
END;
/*TCL Fin--------------------------------------------------------------------------------*/

/*DML Ini--------------------------------------------------------------------------------*/
INSERT INTO "MUNOZSAM"."ZVBAK"
SELECT TOP 10 "VBELN","ERDAT","VKORG","NETWR"
FROM "ZREPC1P"."VBAK";

--VAR_RESULT := 1/0;

VAR_OUT_MESSAGE := TO_NVARCHAR(::ROWCOUNT) || ' Rows affected';
SELECT :VAR_OUT_MESSAGE AS "OUT_MESSAGE" FROM "DUMMY";
/*DML Fin--------------------------------------------------------------------------------*/

END



