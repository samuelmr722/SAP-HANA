create procedure "_SYS_BIC"."CD.LOTES/ZCV_LOTES_CALIDAD/proc" ( IN I_MTART NVARCHAR(4), IN I_VKORG NVARCHAR(4),  OUT var_out "_SYS_BIC"."CD.LOTES/ZCV_LOTES_CALIDAD/proc/tabletype/VAR_OUT" ) language sqlscript sql security definer reads sql data as   /********* Begin Procedure Script ************/ 
 BEGIN 
 
----***************************************************************************************************
--  PAQUETE          : CD
--  FECHA DE CREACION: 15/05/2018
--  MODULO SAP       : WM
--  AUTOR (ID/NOMBRE): MUNOZSAM/Samuel Muñoz - Lineadirecta
--  TITULO           : Calidad de datos para lotes
--  TIPO             : Reporte
--  USO              : Composite en BW
----***************************************************************************************************

LT_LOTES =
SELECT "MATNR", --Numero de material
	"MTART",    --Tipo de material
	"VKORG",    --Organizacion de ventas
	"WERKS",    --Centro de operaciones
	"CHARG",    --Numero de lote
	"LVORM",    --Peticion de borrado
	"J_3ASIZE", --Valor matriz
	"J_4KSCAT", --Categoria de stock
	"ERSDA",    --Fecha de creacion	
	"ERNAM",    --Nombre del responsable de creacion
	"AENAM",	--Nombre del responsable de modificacion
	"LGORT",	--Almacen
	"BWTAR",    --Clase de valoracion
	SUM("CLABS") AS "CLABS",	
	SUM("CUMLM") AS "CUMLM",
	SUM("CINSM") AS "CINSM",	
	SUM("CEINM") AS "CEINM",
	SUM("CSPEM") AS "CSPEM",	
	SUM("CRETM") AS "CRETM",
	SUM("CVMLA") AS "CVMLA",
	SUM("CVMUM") AS "CVMUM",
	SUM("CVMIN") AS "CVMIN",
	SUM("CVMEI") AS "CVMEI",
	SUM("CVMSP") AS "CVMSP",
	SUM("CVMRE") AS "CVMRE",
	SUM("J_3ARESM") AS "J_3ARESM"
FROM "_SYS_BIC"."CD.LOTES/ZCV_LOTES"
	(placeholder."$$I_MTART$$"=>:I_MTART, 
	 placeholder."$$I_VKORG$$"=>:I_VKORG)
	 --WHERE "MATNR" = '000000000000500033'
GROUP BY "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR";

----***************************************************************************************************
---- Recuperacion de datos de configuracion
----***************************************************************************************************
LT_ZWM_ORCASTOCK =
SELECT LTRIM(RTRIM("VKORG",' '),' ') AS "VKORG", 
	   LTRIM(RTRIM("Z4KSCAT",' '),' ') AS "J_4KSCAT"
FROM "SAPABAP1"."ZWM_ORCASTOCK";

LT_ZWM_CDTIPOS =
SELECT LTRIM(RTRIM("ZTIPOS",' '),' ') AS "ZTIPOS", 
	   LTRIM(RTRIM("ZDESTIPOS",' '),' ') AS "ZDESTIPOS"
FROM "SAPABAP1"."ZWM_CDTIPOS"
WHERE "ZGRUPO" = 'LOTE';

----***************************************************************************************************
---- Busqueda de lotes incorrectos, (numericos o con espacios) o (duplicados, numericos o con espacios)
----***************************************************************************************************
IF 1 = 1 THEN
	
	--Lotes numericos o con espacios
	LT_LOTES_INCORRECTOS =
	SELECT *
	FROM :LT_LOTES 
	WHERE "_SYS_BIC".ISNUMERIC("CHARG") = 1 OR "CHARG" LIKE '% %' 
	   OR RIGHT("CHARG",2) <> (LEFT("J_4KSCAT",1) || RIGHT("J_4KSCAT",1))
	;

ELSE

	--Generar llave unica apartir de del material, valor matriz y categoria
	LT_KEY =
	SELECT "MATNR" || "J_3ASIZE" || "J_4KSCAT" AS "KEY","CHARG"
	FROM :LT_LOTES
	GROUP BY "MATNR" || "J_3ASIZE" || "J_4KSCAT","CHARG";
	
	--Lotes duplicados a nivel de material, valor matriz y categoria de stock
	--y numericos o con espacios 	      
	LT_LOTES_INCORRECTOS =
	SELECT *
	FROM :LT_LOTES 
	WHERE ("MATNR" || "J_3ASIZE" || "J_4KSCAT") 
	   IN (SELECT "KEY" FROM :LT_KEY GROUP BY "KEY" HAVING COUNT("KEY")>1)
	AND ("_SYS_BIC".ISNUMERIC("CHARG") = 1 OR "CHARG" LIKE '% %'); 
	
	LT_KEY = SELECT * FROM :LT_KEY WHERE 1 = 2; 

END IF;	      

----***************************************************************************************************
---- 1. Lote errado, desbloqueado y sin inventario en ningún stock
----***************************************************************************************************     

LT_DESBLOQUEADOS_SININVENTARIO =
SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR"	
FROM :LT_LOTES_INCORRECTOS 
WHERE "LVORM" <> 'X'
    AND "CLABS"	= 0
    AND "CUMLM"	= 0
	AND "CINSM"	= 0
	AND "CEINM"	= 0
	AND "CSPEM"	= 0
	AND "CRETM"	= 0
	AND "CVMLA"	= 0
	AND "CVMUM"	= 0
	AND "CVMIN"	= 0
	AND "CVMEI"	= 0
	AND "CVMSP"	= 0
	AND "CVMRE"	= 0
	AND "J_3ARESM" = 0;

----***************************************************************************************************
---- 2. Lote errado y bloqueado con inventario en algun stock
----***************************************************************************************************

LT_BLOQUEADOS_CONINVENTARIO =
SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR"
FROM :LT_LOTES_INCORRECTOS 
WHERE ("LVORM" = 'X') AND
      ("CLABS"	<> 0
    OR "CUMLM"	<> 0
	OR "CINSM"	<> 0
	OR "CEINM"	<> 0
	OR "CSPEM"	<> 0
	OR "CRETM"	<> 0
	OR "CVMLA"	<> 0
	OR "CVMUM"	<> 0
	OR "CVMIN"	<> 0
	OR "CVMEI"	<> 0
	OR "CVMSP"	<> 0
	OR "CVMRE"	<> 0
	OR "J_3ARESM" <> 0);

----***************************************************************************************************
---- 3. Lote errado y desbloqueado con inventario en algun stock
----***************************************************************************************************

LT_DESBLOQUEADOS_CONINVENTARIO =
SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR"
FROM :LT_LOTES_INCORRECTOS 
WHERE ("LVORM" <> 'X') AND
      ("CLABS"	<> 0
    OR "CUMLM"	<> 0
	OR "CINSM"	<> 0
	OR "CEINM"	<> 0
	OR "CSPEM"	<> 0
	OR "CRETM"	<> 0
	OR "CVMLA"	<> 0
	OR "CVMUM"	<> 0
	OR "CVMIN"	<> 0
	OR "CVMEI"	<> 0
	OR "CVMSP"	<> 0
	OR "CVMRE"	<> 0
	OR "J_3ARESM" <> 0);

----***************************************************************************************************
---- 4. Lote correcto bloqueado con inventario en algun stock
----***************************************************************************************************

LT_BUENOS_BLOQUEADOS_CONINVENTARIO =
SELECT LB."MATNR",
	LB."MTART",
	LB."VKORG",
	LB."WERKS",
	LB."CHARG",
	LB."LVORM",	
	LB."J_3ASIZE",
	LB."J_4KSCAT",
	LB."ERSDA",		
	LB."ERNAM",
	LB."AENAM",	
	LB."LGORT",
	LB."BWTAR"
FROM :LT_LOTES AS LB LEFT OUTER JOIN :LT_LOTES_INCORRECTOS AS LM
ON LB."MATNR" = LM."MATNR"
AND LB."J_3ASIZE" = LM."J_3ASIZE"
AND LB."J_4KSCAT" = LM."J_4KSCAT"
AND LB."CHARG" = LM."CHARG"
WHERE (LM."MATNR" IS NULL) AND
      (LB."LVORM" = 'X') AND
      (LB."CLABS"	<> 0
    OR LB."CUMLM"	<> 0
	OR LB."CINSM"	<> 0
	OR LB."CEINM"	<> 0
	OR LB."CSPEM"	<> 0
	OR LB."CRETM"	<> 0
	OR LB."CVMLA"	<> 0
	OR LB."CVMUM"	<> 0
	OR LB."CVMIN"	<> 0
	OR LB."CVMEI"	<> 0
	OR LB."CVMSP"	<> 0
	OR LB."CVMRE"	<> 0
	OR LB."J_3ARESM" <> 0);	

----***************************************************************************************************
---- 5. Valor matriz con mas de un lote en la misma categoria de stock
----***************************************************************************************************

--Generar llave unica apartir de del material, valor matriz, categoria y lote correcto
LT_KEY_LOTECORRECTO =
SELECT LB."MATNR" || LB."J_3ASIZE" || LB."J_4KSCAT" AS "KEY",LB."CHARG"

FROM :LT_LOTES AS LB LEFT OUTER JOIN :LT_LOTES_INCORRECTOS AS LM
ON LB."MATNR" = LM."MATNR"
AND LB."J_3ASIZE" = LM."J_3ASIZE"
AND LB."J_4KSCAT" = LM."J_4KSCAT"
AND LB."CHARG" = LM."CHARG"

WHERE LM."MATNR" IS NULL AND LB."LVORM" <> 'X'
GROUP BY LB."MATNR" || LB."J_3ASIZE" || LB."J_4KSCAT",LB."CHARG";

LT_VM_DOBLELOTE =
SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR"
FROM :LT_LOTES 
WHERE ("MATNR" || "J_3ASIZE" || "J_4KSCAT")
   IN (SELECT "KEY" FROM :LT_KEY_LOTECORRECTO GROUP BY "KEY" HAVING COUNT("KEY")>1);
   
LT_LOTES_INCORRECTOS = SELECT * FROM :LT_LOTES_INCORRECTOS WHERE 1=2;
LT_KEY_LOTECORRECTO = SELECT * FROM :LT_KEY_LOTECORRECTO WHERE 1=2;   

----***************************************************************************************************
---- 6. Valor matriz sin lote en categoria de stock
----***************************************************************************************************

LT_MATERIALCONCATEGORIA =
SELECT L."MATNR",
	L."MTART",
	L."VKORG",
	L."WERKS",
	L."J_3ASIZE",
	Z."J_4KSCAT"
FROM :LT_LOTES AS L INNER JOIN :LT_ZWM_ORCASTOCK AS Z
  ON L."VKORG" = Z."VKORG"
 GROUP BY L."MATNR",
	L."MTART",
	L."VKORG",
	L."WERKS",
	L."J_3ASIZE",
	Z."J_4KSCAT";
	
LT_MATERIALSINCATEGORIA =
SELECT C."MATNR",
	C."MTART",
	C."VKORG",
	C."WERKS",
	C."J_3ASIZE",
	C."J_4KSCAT"
FROM :LT_MATERIALCONCATEGORIA AS C LEFT OUTER JOIN :LT_LOTES AS L
  ON C."MATNR" = L."MATNR"
 AND C."VKORG" = L."VKORG"
 AND C."J_3ASIZE" = L."J_3ASIZE"
 AND C."J_4KSCAT" = L."J_4KSCAT"
 WHERE L."MATNR" IS NULL
 GROUP BY C."MATNR",
	C."MTART",
	C."VKORG",
	C."WERKS",
	C."J_3ASIZE",
	C."J_4KSCAT";
	
LT_MATERIALCONCATEGORIA = SELECT * FROM :LT_MATERIALCONCATEGORIA WHERE 1=2;

----***************************************************************************************************
---- 7. Lote con valor matriz diferente a la clase de valoracion
----***************************************************************************************************

LT_VM_DIFERENTE_CLASEVALORACION =
SELECT LB."MATNR",
	LB."MTART",
	LB."VKORG",
	LB."WERKS",
	LB."CHARG",
	LB."LVORM",	
	LB."J_3ASIZE",
	LB."J_4KSCAT",
	LB."ERSDA",		
	LB."ERNAM",
	LB."AENAM",	
	LB."LGORT",
	LB."BWTAR"
FROM :LT_LOTES AS LB /*LEFT OUTER JOIN :LT_LOTES_INCORRECTOS AS LM
ON LB."MATNR" = LM."MATNR"
AND LB."J_3ASIZE" = LM."J_3ASIZE"
AND LB."J_4KSCAT" = LM."J_4KSCAT"
AND LB."CHARG" = LM."CHARG"
WHERE (LM."MATNR" IS NULL)*/
WHERE RIGHT(LB."J_3ASIZE",LENGTH(LB."BWTAR")) <> LB."BWTAR";

----***************************************************************************************************
---- 8. Categoria de stock incorrecta segun la marca del material
----***************************************************************************************************

LT_CATEGORIA_INCORRECTA =
SELECT LB."MATNR",
	LB."MTART",
	LB."VKORG",
	LB."WERKS",
	LB."CHARG",
	LB."LVORM",	
	LB."J_3ASIZE",
	LB."J_4KSCAT",
	LB."ERSDA",		
	LB."ERNAM",
	LB."AENAM",	
	LB."LGORT",
	LB."BWTAR"
FROM :LT_LOTES AS LB LEFT OUTER JOIN :LT_ZWM_ORCASTOCK AS Z
ON LB."VKORG" = Z."VKORG"
AND LB."J_4KSCAT" = Z."J_4KSCAT"
WHERE (Z."J_4KSCAT" IS NULL);

----***************************************************************************************************
---- Concatenacion de las validaciones para la salida final
----***************************************************************************************************

LT_LOTES = SELECT * FROM :LT_LOTES WHERE 1=2; 

LT_FINAL = 
SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'1' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_DESBLOQUEADOS_SININVENTARIO

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'2' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_BLOQUEADOS_CONINVENTARIO

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'3' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_DESBLOQUEADOS_CONINVENTARIO

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'4' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_BUENOS_BLOQUEADOS_CONINVENTARIO

UNION 

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'5' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_VM_DOBLELOTE

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	'' AS "CHARG",
	'' AS "LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	'' AS "ERSDA",		
	'' AS "ERNAM",
	'' AS "AENAM",	
	'' AS "LGORT",
	'' AS "BWTAR",
	'6' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_MATERIALSINCATEGORIA

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'7' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_VM_DIFERENTE_CLASEVALORACION

UNION

SELECT "MATNR",
	"MTART",
	"VKORG",
	"WERKS",
	"CHARG",
	"LVORM",	
	"J_3ASIZE",
	"J_4KSCAT",
	"ERSDA",		
	"ERNAM",
	"AENAM",	
	"LGORT",
	"BWTAR",
	'8' AS "TIPO",
	 1 AS "MEDIDA"
FROM :LT_CATEGORIA_INCORRECTA
;

--Liberar memoria de las tablas temporables de cada una de las validaciones
LT_DESBLOQUEADOS_SININVENTARIO = SELECT * FROM :LT_DESBLOQUEADOS_SININVENTARIO WHERE 1=2;
LT_BLOQUEADOS_CONINVENTARIO = SELECT * FROM :LT_BLOQUEADOS_CONINVENTARIO WHERE 1=2;
LT_DESBLOQUEADOS_CONINVENTARIO = SELECT * FROM :LT_DESBLOQUEADOS_CONINVENTARIO WHERE 1=2;
LT_BUENOS_BLOQUEADOS_CONINVENTARIO = SELECT * FROM :LT_BUENOS_BLOQUEADOS_CONINVENTARIO WHERE 1=2;
LT_VM_DOBLELOTE = SELECT * FROM :LT_VM_DOBLELOTE WHERE 1=2;
LT_MATERIALSINCATEGORIA = SELECT * FROM :LT_MATERIALSINCATEGORIA WHERE 1=2;

----***************************************************************************************************
---- Recuperacion de los tipos para la descripcion y configuracion de salida
----***************************************************************************************************

VAR_OUT =
SELECT F."MATNR",  --Numero de material
	F."MTART",     --Tipo de material
	F."VKORG",     --Organizacion de ventas
	F."WERKS",     --Centro de operaciones
	F."CHARG",     --Numero de lote
	F."LVORM",     --Peticion de borrado
	F."J_3ASIZE",  --Valor matriz
	F."J_4KSCAT",  --Categoria de stock
	F."ERSDA",     --Fecha de creacion	
	F."ERNAM",     --Nombre del responsable de creacion
	F."AENAM",	   --Nombre del responsable de modificacion
	F."LGORT",     --Almacen
	F."BWTAR",     --Clase de valoracion
	T."ZDESTIPOS" AS "TIPO", --Tipo de validacion, descripion obtenida de la configuracion
	COUNT(F."MEDIDA") AS "MEDIDA"    --Contador de registros	
FROM :LT_FINAL F INNER JOIN :LT_ZWM_CDTIPOS T ON F."TIPO" = T."ZTIPOS"
GROUP BY F."MATNR",
	F."MTART",
	F."VKORG",
	F."WERKS",
	F."CHARG",
	F."LVORM", 
	F."J_3ASIZE",
	F."J_4KSCAT", 
	F."ERSDA",
	F."ERNAM",
	F."AENAM",
	F."LGORT",
	F."BWTAR",
	T."ZDESTIPOS";

END /********* End Procedure Script ************/