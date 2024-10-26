-- FAZA 1 - Priprava katastra stanovanjskih stavb
/*
A
Del A pripravi vse podatke, ki so potrebni za pripravo katastra stanovanjskih stavb:
1. TLORIS STAVBE NA PARCELI
Stavba lahko stoji na več parcelah in je treba izračunat seštev teh tlorisov.
Najprej bomo seštevili tlorise iz sloja poligon in iz sloja točka (A1), 
potem pa bomo šešteli površine v sloju poligon (A2).
2. ŠTEVILKA PRITLIČNE ETAŽE
Podatek o številu etaž nam kaže skupno število etaž. 
Da lahko izračunamo število nadzemnih etaž potrebujemo podatek o tem katera etaža je pritlična (A3).
*/
-------------------------------------------------------------
--A1
	drop table if exists 	SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG; 
	CREATE TABLE 			SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG AS
	
	with cte_union AS (
	select 
		EID_STAVBA,
		POVRSINA,
		GEOM
	FROM BASEMAP.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON
	UNION ALL 
	select 
		eid_stavb0::bigint AS EID_STAVBA,
		povrsina,
		ST_Multi(ST_Buffer(geom, 1)) AS geom
	from	
	scratch.kn_slo_parcele_slo_stavbe_parcele_tocka
	
	)
	
	SELECT
		EID_STAVBA,
		SUM(POVRSINA) AS POVRSINA_ZPS,
		ST_UNION (GEOM) AS GEOM
	FROM
		cte_union
	GROUP BY
		EID_STAVBA;
	
	CREATE INDEX ON		SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG USING GIST (GEOM);
	ALTER TABLE 		SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG ADD COLUMN GID SERIAL PRIMARY KEY;
--------------------------------------------------------------------------------------------------------------------
--A2
	DROP TABLE IF EXISTS 	SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG;
	CREATE TABLE 			SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG AS
	
	SELECT
		EID_STAVBA,
		SUM(POVRSINA) AS POVRSINA_ZPS,
		ST_UNION (GEOM) AS GEOM
	FROM
		BASEMAP.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON
	GROUP BY
		EID_STAVBA;
	
	CREATE INDEX ON 	SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG USING GIST (GEOM);
	ALTER TABLE 		SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG ADD COLUMN GID SERIAL PRIMARY KEY;
---------------------------------------------------------------------------------------------------------------------------------
--A3
-- združi etaže v en sloj in za stavbo poglej najnižjo vrednost
drop table if exists scratch.kn_slo_stavbe_slo_etaze_merge;
create table scratch.kn_slo_stavbe_slo_etaze_merge as

with cte_zdruzi as (
SELECT
		EID_STAVBA,
		stevilka_e
FROM
		scratch.kn_slo_stavbe_slo_etaze_null
	WHERE PRITLICNA_ = 1
		UNION ALL
SELECT
		EID_STAVBA,
		stevilka_e
FROM
		scratch.kn_slo_stavbe_slo_etaze_POLIGON
WHERE PRITLICNA_ = 1
)
select EID_STAVBA::bigint,
	min(stevilka_e) as STEVILKA_PRITLICNE_ETAZE

from cte_zdruzi
group by EID_STAVBA;


-----------------------------------------------------------------------------------------------------------------------------------
--B
/*
Del B naredi sloj z vsemi geometrijami. Ta spoj v nadaljevanju uporabimo za sestavo katastra in
tudi za nadometne geometrije. Izberemo in izračunamo atribute potrebe za analizo (B1) in
potem združimo vse geometrije glede na sloj Centroid_stavbe (B2). 
Na koncu izberemo občine za analizo (B3). */
----------------------------------------------------------------
--B1
DROP TABLE IF EXISTS 	rezultati.geom;
CREATE TABLE 			rezultati.geom AS

SELECT
	A.EID_STAVBA::text,
	KO_ID,
	A.ST_STAVBE,
	A.STEVILO_ETAZ,
	A.STEVILO_STANOVANJ,
	A.LETO_IZGRADNJE,
	A.STEVILO_POSLOVNIH_PROSTOROV,
	A.BRUTO_TLORISNA_POVRSINA,
	A.EID_OBCINA,
/*	Ker vemo da obstajajo stavbe, ki nimajo zapisa o površini stavbe na parceli,
	zastavljen je pogoj da v tem primeru prevzamemo vrednost 0.1 kako bi se izognili delitviji z nulo v nadaljnih korakih.	*/
	CASE WHEN F.POVRSINA_ZPS > 0 THEN F.POVRSINA_ZPS
	ELSE 0.1
	END POVRSINA_ZPS_MERGE,
	
	G.POVRSINA_ZPS,
	PODROBNA_NAMENSKA_RABA_ID,
	ETAZE.STEVILKA_PRITLICNE_ETAZE,
 
/*	IZRAČUN ŠTEVILA NADZEMNIH ETAŽ 
	Izračun je narejen po formuli: skupno število vseh etaž - številka etaže, ki je pritlična +1.
	Dodan je pogj da če nimamo pritlične etaže, se za število nademnih etaž prevzame skupno število etaž.
	Če ni niti te informacije je vrednost NULL.	*/
	CASE WHEN ETAZE.STEVILKA_PRITLICNE_ETAZE IS NOT NULL AND STEVILO_ETAZ IS NOT NULL
	THEN A.STEVILO_ETAZ - ETAZE.STEVILKA_PRITLICNE_ETAZE + 1 
	WHEN STEVILO_ETAZ IS NOT NULL THEN A.STEVILO_ETAZ
	ELSE NULL
	END stevilo_nadzemnih_etaz,
	
	
	ST_AREA (B.GEOM) AS AREA_STAVBE_NADZEMNI_TLORIS_POLIGON, --povrsina_Nadzemni_tloris
	ST_AREA (C.GEOM) AS AREA_STAVBE_TLORIS_POLIGON,  --povrsina_Tloris_stavbe
	ST_AREA (D.GEOM) AS AREA_DTM_BU_STAVBE_P,  --povrsina_Tloris_DTM
	ST_AREA (E.GEOM) AS AREA_STAVBE_TLORIS_ZPS_POLIGON,  -- povrsina_Tloris_ZPS
	ST_AREA (G.GEOM) AS AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG, --povrsina_Tloris_stavbe_parcele_poly
	ST_AREA (F.GEOM) AS AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG, --povrsina_Tloris_stavbe_parcele_MERGE
---------------------------------------------------------------------------------------------------------------------------
--B2	
	CASE WHEN C.GEOM IS NOT NULL THEN 1 					ELSE 0 END AREA_BOOL_STAVBE_TLORIS_POLIGON,
	CASE WHEN D.GEOM IS NOT NULL THEN 1 					ELSE 0 END AREA_BOOL_DTM_BU_STAVBE_P,
	CASE WHEN E.GEOM IS NOT NULL THEN 1 					ELSE 0 END AREA_BOOL_STAVBE_TLORIS_ZPS_POLIGON,
	CASE WHEN G.GEOM IS NOT NULL THEN 1 					ELSE 0 END AREA_BOOL_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG,

	
	A.GEOM AS Centrid_stavbe,
	B.GEOM AS Nadzemni_tloris,
	C.GEOM AS Tloris_stavbe,
	D.GEOM AS Tloris_DTM,
	E.GEOM AS Tloris_ZPS,
	G.GEOM AS Tloris_stavbe_parcele,
	F.GEOM AS Tloris_stavbe_parcele_merge

FROM
	BASEMAP.KN_SLO_STAVBE_STAVBE_TOCKA A
	LEFT JOIN SCRATCH.KN_SLO_STAVBE_SLO_STAVBE_NADZEMNI_TLORIS_POLIGON B ON A.EID_STAVBA = B.EID_STAVBA::BIGINT
	LEFT JOIN SCRATCH.KN_SLO_STAVBE_SLO_STAVBE_TLORIS_POLIGON C ON A.EID_STAVBA = C.EID_STAVBA::BIGINT
	LEFT JOIN (
		SELECT
			*
		FROM
			BASEMAP.DTM_BU_STAVBE_P
		WHERE
			SID <> 0
	) D ON SUBSTRING(A.EID_STAVBA::TEXT, 10, 8)::BIGINT = D.SID
	LEFT JOIN SCRATCH.KN_SLO_STAVBE_SLO_STAVBE_TLORIS_ZPS_POLIGON E ON A.EID_STAVBA = E.EID_STAVBA::BIGINT
	LEFT JOIN SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG F ON A.EID_STAVBA = F.EID_STAVBA
	LEFT JOIN SCRATCH.KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG G ON A.EID_STAVBA = G.EID_STAVBA
	--LEFT JOIN SCRATCH.KN_SLO_STAVBE_STAVBE_POLY H ON A.EID_STAVBA = H.EID_STAVBA
	LEFT JOIN scratch.kn_slo_stavbe_slo_etaze_merge ETAZE ON A.EID_STAVBA = ETAZE.EID_STAVBA

	LEFT JOIN (SELECT * FROM basemap.kn_slo_nam_raba_poligon) NAM_RABA  on ST_INTERSECTS(A.GEOM, NAM_RABA.GEOM)

-- B3	
WHERE
	EID_OBCINA IN (
		'110200000110278814',
		'110200000110274821',
		'110200000110276107'
	)
;
------------------------------------------------------------------------------------------------------------
--C
/*
Del C je priprava katastra nepremičnin.
Spet izberemo atribute (C1) in potem je postopek sestave slojev (C2). */
--------------------------------------------------
--C1
DROP TABLE IF EXISTS rezultati.KATASTER_NEPREMICNIN;
CREATE TABLE rezultati.KATASTER_NEPREMICNIN AS

WITH cte_reklasifikacija as (
SELECT
	EID_STAVBA,
	KO_ID,
	ST_STAVBE,
	STEVILO_ETAZ,
	STEVILO_STANOVANJ,
	LETO_IZGRADNJE,
	STEVILO_POSLOVNIH_PROSTOROV,
	BRUTO_TLORISNA_POVRSINA,
	EID_OBCINA,
	POVRSINA_ZPS_MERGE,
	POVRSINA_ZPS,
	STEVILKA_PRITLICNE_ETAZE,
	PODROBNA_NAMENSKA_RABA_ID,
	stevilo_nadzemnih_etaz,
	AREA_STAVBE_NADZEMNI_TLORIS_POLIGON,
	AREA_STAVBE_TLORIS_POLIGON,
	AREA_DTM_BU_STAVBE_P,
	AREA_STAVBE_TLORIS_ZPS_POLIGON,
	AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG,
	AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG,
	Centrid_stavbe,
	Nadzemni_tloris,
	Tloris_stavbe,
	Tloris_DTM,
	Tloris_ZPS,
	Tloris_stavbe_parcele,
	Tloris_stavbe_parcele_merge,
------------------------------------------------------
--C2
	--pogoj A
	CASE WHEN Tloris_ZPS IS NOT NULL 
				AND ABS(AREA_STAVBE_TLORIS_ZPS_POLIGON - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE < 0.3 -- Faktor_geom_tsp
					THEN 1
		--pogoj B
		WHEN Nadzemni_tloris IS NOT NULL
			AND ABS(AREA_STAVBE_NADZEMNI_TLORIS_POLIGON - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE < 0.3 -- Faktor_geom_tsp
				THEN 2
		--pogoj C
		WHEN Tloris_stavbe_parcele IS NOT NULL
			AND ABS(AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE < 0.3 -- Faktor_geom_tsp
				THEN 3
		-- pogoj D
		WHEN 	
		Tloris_ZPS IS NOT NULL AND 	
		ABS (
				(AREA_STAVBE_TLORIS_ZPS_POLIGON -  
					-- povprečje površin
					((AREA_STAVBE_TLORIS_POLIGON + AREA_DTM_BU_STAVBE_P + AREA_STAVBE_TLORIS_ZPS_POLIGON + AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG) -- seštevek površin
					/																																		-- deljeno z				
				(AREA_BOOL_STAVBE_TLORIS_POLIGON + AREA_BOOL_DTM_BU_STAVBE_P +	AREA_BOOL_STAVBE_TLORIS_ZPS_POLIGON + AREA_BOOL_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG)	-- številom stolpcev s površinami
				)
				) 
				/ 
				AREA_STAVBE_TLORIS_ZPS_POLIGON) < 0.05  -- Faktor_geom
		THEN 4					
		-- pogoj E
		WHEN 	
		Tloris_stavbe_parcele IS NOT NULL AND			
		ABS	(				(AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG - 
		(
			(	AREA_STAVBE_TLORIS_POLIGON +
				AREA_DTM_BU_STAVBE_P +
				AREA_STAVBE_TLORIS_ZPS_POLIGON +
				AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG) /
				(	
				AREA_BOOL_STAVBE_TLORIS_POLIGON +
				AREA_BOOL_DTM_BU_STAVBE_P +
				AREA_BOOL_STAVBE_TLORIS_ZPS_POLIGON +
				AREA_BOOL_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG)
						
				)) / AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG) < 0.05 -- Faktor_geom
		THEN 5					
		-- pogoj F
		WHEN Tloris_stavbe IS NOT NULL
			AND ABS(AREA_STAVBE_TLORIS_POLIGON - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE < 0.3 -- Faktor_geom_tsp
				THEN 7
		-- pogoj G
		WHEN Tloris_DTM IS NOT NULL
			AND ABS(AREA_DTM_BU_STAVBE_P - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE < 0.3 -- Faktor_geom_tsp
				THEN 8
		-- pogoj H
        WHEN POVRSINA_ZPS_MERGE = 0.1
            AND AREA_STAVBE_TLORIS_ZPS_POLIGON IS NOT NULL
            AND AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG IS NOT NULL 
            AND AREA_STAVBE_TLORIS_ZPS_POLIGON = AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG
                THEN 9
        -- pogoj I
		WHEN POVRSINA_ZPS_MERGE = 0.1
            AND (AREA_STAVBE_TLORIS_ZPS_POLIGON IS NULL
            OR AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG IS NULL)
            AND AREA_STAVBE_TLORIS_ZPS_POLIGON <> AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG
            AND AREA_STAVBE_NADZEMNI_TLORIS_POLIGON = AREA_STAVBE_TLORIS_POLIGON
                THEN 10
		-- pogoj J	
        WHEN Nadzemni_tloris IS NOT NULL
			AND ABS(AREA_STAVBE_NADZEMNI_TLORIS_POLIGON - POVRSINA_ZPS_MERGE)/POVRSINA_ZPS_MERGE > 0.3 -- Faktor_geom_tsp
			AND AREA_STAVBE_NADZEMNI_TLORIS_POLIGON = AREA_DTM_BU_STAVBE_P 
                THEN 11
		-- pogoj K
		WHEN Nadzemni_tloris IS NOT NULL
		THEN  12
		-- pogoj L
		WHEN Tloris_ZPS IS NOT NULL
		AND Tloris_stavbe_parcele IS NOT NULL
		AND AREA_STAVBE_TLORIS_ZPS_POLIGON = AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG
			THEN 6
		-- pogoj M
		ELSE 7

		END geom_clas_id
---------------------------------------------------------------------------------------------------------------------
--D
/*
Del D določi oceno zanesljivosti za pogoje sestave tlorisov stavb. */
------------------------------------------
FROM rezultati.geom
)
select 

	EID_STAVBA,
	KO_ID,
	ST_STAVBE,
	STEVILO_ETAZ,
	STEVILO_STANOVANJ,
	LETO_IZGRADNJE,
	STEVILO_POSLOVNIH_PROSTOROV,
	BRUTO_TLORISNA_POVRSINA,
	EID_OBCINA,
	POVRSINA_ZPS_MERGE,
	POVRSINA_ZPS,
	STEVILKA_PRITLICNE_ETAZE,
	stevilo_nadzemnih_etaz,
	PODROBNA_NAMENSKA_RABA_ID,
	AREA_STAVBE_NADZEMNI_TLORIS_POLIGON,
	AREA_STAVBE_TLORIS_POLIGON,
	AREA_DTM_BU_STAVBE_P,
	AREA_STAVBE_TLORIS_ZPS_POLIGON,
	AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_AGG,
	AREA_KN_SLO_PARCELE_STAVBE_PARCELE_POLIGON_MERGE_AGG,
	
b.*,

CASE 
	WHEN geom_clas_id = 1 THEN Tloris_ZPS
	WHEN geom_clas_id = 2 THEN Nadzemni_tloris
	WHEN geom_clas_id = 3 THEN Tloris_stavbe_parcele
	WHEN geom_clas_id = 4 THEN Tloris_ZPS
	WHEN geom_clas_id = 5 THEN Tloris_stavbe_parcele
	WHEN geom_clas_id = 6 THEN Tloris_ZPS
	WHEN geom_clas_id = 7 THEN Tloris_stavbe
	WHEN geom_clas_id = 8 THEN Tloris_DTM
	WHEN geom_clas_id = 9 THEN Tloris_ZPS
	WHEN geom_clas_id = 10 THEN Nadzemni_tloris
	WHEN geom_clas_id = 11 THEN Nadzemni_tloris
	WHEN geom_clas_id = 12 THEN Nadzemni_tloris
	
END GEOM
from
cte_reklasifikacija a
left join scratch.kn_slo_clas_geom b using (geom_clas_id);

-- dodaja index za hitrejšo obdelavo podatkov 
-- dodaje stolpce za nadometno geometrijo in površino tlorisa stavbe

CREATE INDEX ON rezultati.KATASTER_NEPREMICNIN USING GIST (GEOM);
ALTER TABLE rezultati.KATASTER_NEPREMICNIN ADD COLUMN GID SERIAL PRIMARY KEY;
ALTER TABLE rezultati.KATASTER_NEPREMICNIN ADD COLUMN IF NOT EXISTS NADOMESTNA_GEOMETRIJA TEXT;
ALTER TABLE rezultati.KATASTER_NEPREMICNIN ADD COLUMN IF NOT EXISTS povrsina NUMERIC;
UPDATE rezultati.KATASTER_NEPREMICNIN
SET povrsina = ST_Area(geom);
-----------------------------------------------------------------------------------------
--E
/* Del E odstrani nestanovanjske stavbe iz katastra nepremičnin in 
jih da v novo tabelo kataster stanovanjskih stavb. */
---------------------------
ALTER TABLE rezultati.KATASTER_NEPREMICNIN 
ADD COLUMN stevilo_prekrivanj INTEGER;

/* izračun števila sosednjih stavb je v tem koraku potreben zaradi 
odstaranitve nestanovanjskih stavb. */
WITH prekrivanja AS (
    SELECT 
        a.EID_STAVBA AS object_id,
        COUNT(b.EID_STAVBA) AS stevilo_prekrivanj
    FROM 
        rezultati.KATASTER_NEPREMICNIN a
    LEFT JOIN 
        rezultati.KATASTER_NEPREMICNIN b
    ON 
        ST_DWithin(a.geom, b.geom, 1.5)  -- Radijus od 2 metra
        AND a.EID_STAVBA <> b.EID_STAVBA  -- Ne uspoređuj isti objekt s njim samim
    GROUP BY 
        a.EID_STAVBA
)
UPDATE 
    rezultati.KATASTER_NEPREMICNIN g
SET 
    stevilo_prekrivanj = COALESCE(p.stevilo_prekrivanj, 0)
FROM 
    prekrivanja p
WHERE 
    g.EID_STAVBA = p.object_id;
--priprava tabele za kataster nestanovanjskih stavb
DROP TABLE IF EXISTS rezultati.KATASTER_STANOVANJSKIH_STAVB;
CREATE TABLE rezultati.KATASTER_STANOVANJSKIH_STAVB AS	
SELECT *
FROM rezultati.KATASTER_NEPREMICNIN
WHERE 
STEVILO_STANOVANJ > 0
--pogoji za stanovanjske stavbe
AND podrobna_namenska_raba_id <= 5
AND NOT(povrsina > 400 AND STEVILO_STANOVANJ <= 2)
AND NOT(STEVILO_STANOVANJ = 1 
        AND stevilo_nadzemnih_etaz = 1 
        AND stevilo_prekrivanj <= 1  
        AND povrsina < 75)
AND NOT(STEVILO_STANOVANJ = 1 AND povrsina < 45 AND stevilo_prekrivanj > 3)
AND NOT(povrsina < 35
	AND STEVILO_STANOVANJ = 1
	AND stevilo_nadzemnih_etaz = 1
	AND stevilo_prekrivanj >= 1 );

CREATE INDEX ON rezultati.KATASTER_STANOVANJSKIH_STAVB USING GIST (GEOM);
ALTER TABLE rezultati.KATASTER_STANOVANJSKIH_STAVB ADD COLUMN ID_ss SERIAL PRIMARY KEY;
----------------------------------------------------------------------------------------------
--F
/* Del F PRIPRAVI LOOKUP TABELO ZA NADOMESTNE GEOMETRIJE (potrena za ročni pregled) */
DROP TABLE IF EXISTS rezultati.NADOMESTNA_GEOMETRIJA;

CREATE TABLE IF NOT EXISTS rezultati.NADOMESTNA_GEOMETRIJA (
	GID SERIAL PRIMARY KEY,
	NADOMESTNA_GEOMETRIJA TEXT);
INSERT INTO
	rezultati.NADOMESTNA_GEOMETRIJA (NADOMESTNA_GEOMETRIJA)
VALUES
	('Tloris zemljišča pod stavbo'),
	('Tloris nadzemnega dela stavbe'),
	('Tloris stavbe na paceli'),
	('Tloris stavbe'),
	('Tloris stavbe iz Državnega topografskega modela');
---------------------------------------------------------------------------------------------
-- Posodobitev katastra stanovanjskih stavb
--G
/* Del G poskrbi, da se na podlagi ročneg pregleda posodobijo tlorisi.
Preverja vrednost v stolpcu nadometna geometrija in prilagi geometrije. */
------------------------------------------
UPDATE rezultati.KATASTER_STANOVANJSKIH_STAVB A
SET
	GEOM = SUB.GEOM
FROM
	(
		SELECT
			EID_STAVBA, Tloris_ZPS AS GEOM
		FROM
			rezultati.geom
	) SUB
WHERE
	NADOMESTNA_GEOMETRIJA = 'Tloris zemljišča pod stavbo'
	AND A.EID_STAVBA = SUB.EID_STAVBA;

UPDATE rezultati.KATASTER_STANOVANJSKIH_STAVB A
SET
	GEOM = SUB.GEOM
FROM
	(
		SELECT
			EID_STAVBA, Nadzemni_tloris AS GEOM
		FROM
			rezultati.geom
	) SUB
WHERE
	NADOMESTNA_GEOMETRIJA = 'Tloris nadzemnega dela stavbe'
	AND A.EID_STAVBA = SUB.EID_STAVBA;

UPDATE rezultati.KATASTER_STANOVANJSKIH_STAVB A
SET
	GEOM = SUB.GEOM
FROM
	(
		SELECT
			EID_STAVBA, Tloris_stavbe_parcele AS GEOM
		FROM
			rezultati.geom
	) SUB
WHERE
	NADOMESTNA_GEOMETRIJA = 'Tloris stavbe na paceli'
	AND A.EID_STAVBA = SUB.EID_STAVBA;

UPDATE rezultati.KATASTER_STANOVANJSKIH_STAVB A
SET
	GEOM = SUB.GEOM
FROM
	(
		SELECT
			EID_STAVBA, 
			Tloris_stavbe AS GEOM
		FROM
			rezultati.geom
	) SUB
WHERE
	NADOMESTNA_GEOMETRIJA = 'Tloris stavbe'
	AND A.EID_STAVBA = SUB.EID_STAVBA;

UPDATE rezultati.KATASTER_STANOVANJSKIH_STAVB A
SET
	GEOM = SUB.GEOM
FROM
	(
		SELECT
			EID_STAVBA, 
			Tloris_DTM AS GEOM
		FROM
			rezultati.geom
	) SUB
WHERE
	NADOMESTNA_GEOMETRIJA = 'Tloris stavbe iz Državnega topografskega modela'
	AND A.EID_STAVBA = SUB.EID_STAVBA;

--------------------------------------------------------------------------------------------
-- FAZA 2 - Analiza stanovanjskih stavb
--H
-- Izračun števila sosednjih stavb
WITH sosedi AS (
    SELECT 
        a.EID_STAVBA AS object_id,
        COUNT(b.EID_STAVBA) AS stevilo_prekrivanj
    FROM 
        rezultati.Kataster_stanovanjskih_stavb a
    LEFT JOIN 
        rezultati.Kataster_stanovanjskih_stavb b
    ON 
        ST_DWithin(a.geom, b.geom, 1.5)
        AND a.EID_STAVBA <> b.EID_STAVBA 
    GROUP BY 
        a.EID_STAVBA
)
UPDATE 
    rezultati.Kataster_stanovanjskih_stavb g
SET 
    stevilo_prekrivanj = COALESCE(p.stevilo_prekrivanj, 0)
FROM 
    sosedi p
WHERE 
    g.EID_STAVBA = p.object_id;
---------------------------------------------------------------------------
--Parameti in komponente 
--I
--razdelitev stavb glede na način grupiranja
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb 
ADD COLUMN IF NOT EXISTS nacin_grupiranja TEXT;

UPDATE rezultati.Kataster_stanovanjskih_stavb
SET nacin_grupiranja = 
CASE
    WHEN stevilo_prekrivanj = 0 THEN 'Prostostostoječa stavba'
    WHEN stevilo_prekrivanj > 0 THEN 'Povezana stavba'
END;
--------------------------------------------------
-- J
--Izračun parametrov oblike
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb 
ADD COLUMN IF NOT EXISTS MBG_sirina DOUBLE PRECISION,  -- širina stavbe
ADD COLUMN IF NOT EXISTS MBG_dolzina DOUBLE PRECISION,  -- dolžina stavbe
ADD COLUMN IF NOT EXISTS MBG_ratio DOUBLE PRECISION; -- razmerje med dolžino iin širino stavbe

WITH cte_test_mbg AS (
    SELECT 
        EID_STAVBA,
        ST_Boundary(ST_OrientedEnvelope(geom)) AS geom
    FROM 
        rezultati.Kataster_stanovanjskih_stavb),

cte_test_poligon AS(
SELECT
	EID_STAVBA,
	ST_MakeLine(
  ST_PointN(b.geom,gs.pt),
  ST_PointN(b.geom,gs.pt+1)
) AS geom
	FROM cte_test_mbg b
CROSS JOIN LATERAL generate_series(1,2) gs(pt)
	),

cte_dolzina AS (
	SELECT
EID_STAVBA,
ST_Length(geom) AS stranica
FROM cte_test_poligon),
	bbox_calculations AS(
SELECT 
EID_STAVBA,
min(stranica) AS sirina,
max(stranica) AS dolzina
FROM cte_dolzina
GROUP BY EID_STAVBA)
	--K2_C2
UPDATE 
    rezultati.Kataster_stanovanjskih_stavb g
SET 
    MBG_sirina = bc.sirina,
    MBG_dolzina = bc.dolzina,
	MBG_ratio = bc.dolzina / bc.sirina
    
FROM 
    bbox_calculations bc
WHERE 
    g.EID_STAVBA = bc.EID_STAVBA;
-------------------------------------
-- korekcija vrednosti za stavbe nepravilnih oblik
DROP TABLE IF EXISTS scratch.dump;	
CREATE TABLE scratch.dump AS
SELECT
	eid_stavba,
	stevilo_prekrivanj,
        (ST_Dump(ST_Buffer(geom,-0.01))).geom AS geom, 
        MBG_dolzina, 
        MBG_sirina,
		povrsina,
	STEVILO_STANOVANJ
	FROM rezultati.Kataster_stanovanjskih_stavb;
	
CREATE INDEX ON scratch.dump USING GIST(GEOM);
WITH AggregatedPolygon AS (
    SELECT
        ST_Union(geom) AS geom
    FROM
        scratch.dump
	GROUP BY
        eid_stavba
),	
MedialAxis AS(
   SELECT
        eid_stavba,
		stevilo_prekrivanj,
	   	povrsina,
        ST_Length(ST_ApproximateMedialAxis(geom)) AS medial_axis_length, 
        MBG_dolzina, 
        MBG_sirina,
		povrsina,
		STEVILO_STANOVANJ
    FROM
        scratch.dump
    WHERE
        stevilo_prekrivanj = 0 AND STEVILO_STANOVANJ >= 10 AND povrsina >1000
	   ),
PercentageDifference AS(
    SELECT
        eid_stavba,
		stevilo_prekrivanj,
        medial_axis_length,
        MBG_dolzina,
        MBG_sirina,
        (100 - (MBG_dolzina * 100 / medial_axis_length)) AS difference_percentage
    FROM
        MedialAxis
    WHERE
        medial_axis_length > 0 
),
UpdatedValues AS (
    SELECT
        pd.eid_stavba,
        pd.medial_axis_length,
        pd.MBG_dolzina,
        pd.MBG_sirina AS original_sirina,
        CASE
            WHEN pd.medial_axis_length > pd.MBG_dolzina AND pd.difference_percentage > 50 THEN
                pd.MBG_sirina - (pd.MBG_sirina * (CASE WHEN pd.difference_percentage < 0 THEN 0 ELSE pd.difference_percentage END / 100))
            ELSE
                pd.MBG_sirina
        END AS updated_sirina
    FROM
        PercentageDifference pd
)
UPDATE
    rezultati.Kataster_stanovanjskih_stavb AS original
SET
    MBG_sirina = uv.updated_sirina,
	MBG_dolzina = uv.medial_axis_length,
    MBG_ratio = CASE 
        WHEN uv.medial_axis_length > uv.MBG_dolzina AND (100 - (uv.MBG_dolzina * 100 / uv.medial_axis_length)) > 50 THEN
            uv.medial_axis_length / uv.updated_sirina
        ELSE
            original.MBG_ratio
    END
FROM
    UpdatedValues uv
WHERE
    original.eid_stavba = uv.eid_stavba;

------------------------------------------------------------------------------------------------------
-- K
--komponente povezanih stavb
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb 
ADD COLUMN IF NOT EXISTS komponente TEXT;

UPDATE rezultati.Kataster_stanovanjskih_stavb AS b1
SET komponente = 'krajne_v'
FROM rezultati.Kataster_stanovanjskih_stavb AS b2
WHERE b1.stevilo_prekrivanj = 1
AND b2.stevilo_prekrivanj = 2
AND ST_DWithin(b1.geom, b2.geom, 2)
AND b1.stevilo_prekrivanj > 0;

UPDATE rezultati.Kataster_stanovanjskih_stavb  AS b1
SET komponente = 'krajne_a'
FROM rezultati.Kataster_stanovanjskih_stavb  AS b2
WHERE b1.stevilo_prekrivanj = 1
AND b2.stevilo_prekrivanj = 3
AND ST_DWithin(b1.geom, b2.geom, 2)
AND b1.stevilo_prekrivanj > 0;

UPDATE rezultati.Kataster_stanovanjskih_stavb as b1
SET komponente = 'dvojcek_blok'
FROM rezultati.Kataster_stanovanjskih_stavb as b2
WHERE b1.stevilo_prekrivanj = 1
AND b2.stevilo_prekrivanj = 1
AND ST_DWithin(b1.geom, b2.geom, 2)
AND b1.stevilo_prekrivanj > 0;  

UPDATE rezultati.Kataster_stanovanjskih_stavb AS b1
SET komponente = 'krajne_a'
FROM rezultati.Kataster_stanovanjskih_stavb AS b2
WHERE b1.stevilo_prekrivanj = 2
AND b2.stevilo_prekrivanj = 3
AND ST_DWithin(b1.geom, b2.geom, 2)
AND b1.stevilo_prekrivanj > 0;

UPDATE rezultati.Kataster_stanovanjskih_stavb
SET komponente = 'vmesne_v'
WHERE stevilo_prekrivanj = 2
AND komponente IS NULL
AND stevilo_prekrivanj > 0;

UPDATE rezultati.Kataster_stanovanjskih_stavb
SET komponente = 'vmesne_a'
WHERE stevilo_prekrivanj > 0
AND komponente IS NULL;
-------------------------------------------------------------------------
--L
-- določanje stavbnih skupin
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb
ADD COLUMN IF NOT EXISTS cluster_id INTEGER;
	
WITH clusters AS (
    SELECT 
        EID_STAVBA, 
        ST_ClusterDBSCAN(geom, eps := 2, minpoints := 2) OVER () AS cluster_id
    FROM 
        rezultati.Kataster_stanovanjskih_stavb
)
UPDATE rezultati.Kataster_stanovanjskih_stavb AS t
SET cluster_id = c.cluster_id
FROM clusters AS c
WHERE t.EID_STAVBA = c.EID_STAVBA;
-------------------------------------------------------------------------------
-- FAZA 3 - Klasifikacija tipologija stanovanjskih stavb
--priprava nove tabele za klasifikacijo stavb
DROP TABLE IF EXISTS rezultati.Klasifikacija_stanovanjskih_stavb;
CREATE TABLE rezultati.Klasifikacija_stanovanjskih_stavb AS
SELECT *
FROM rezultati.Kataster_stanovanjskih_stavb;
CREATE INDEX ON rezultati.Klasifikacija_stanovanjskih_stavb USING GIST (GEOM);
--stolpec za vpis tipologije
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb 
ADD COLUMN IF NOT EXISTS tipologija TEXT;

-- M
--Klasifikacija prostostoječih stavb
UPDATE rezultati.Kataster_stanovanjskih_stavb 
SET tipologija =
    CASE
--stolpnica
	WHEN MBG_ratio <= 1.55 AND 
	MBG_sirina > 15 AND MBG_sirina <= 40.5 AND
	MBG_dolzina > 15 AND MBG_dolzina <= 40.5 AND
	stevilo_nadzemnih_etaz >= 8 AND 
	STEVILO_STANOVANJ >= 25 AND 
	povrsina < 1000 THEN 'Stolpnica'
       
--stolpic
	WHEN MBG_ratio <= 1.55 AND 
	MBG_sirina > 10 AND MBG_sirina <= 25 AND
	MBG_dolzina > 10 AND MBG_dolzina <= 25 AND
	stevilo_nadzemnih_etaz <= 8 AND 
	STEVILO_STANOVANJ >= 10 AND 
	povrsina <= 450 THEN 'Stolpič'

--vila blok
	WHEN MBG_ratio <= 3 AND 
	MBG_sirina >= 9 AND MBG_sirina <= 35 AND
	MBG_dolzina >= 9 AND MBG_dolzina <= 35 AND
	stevilo_nadzemnih_etaz >= 3 AND
	stevilo_nadzemnih_etaz <= 5 AND 
	STEVILO_STANOVANJ >= 6 AND STEVILO_STANOVANJ <= 12 AND
	povrsina <= 450 THEN 'Vila blok'
	
--ozki blok
	WHEN MBG_ratio > 1.5 AND 
	MBG_sirina >= 8 AND MBG_sirina <= 12 AND
	stevilo_nadzemnih_etaz >= 4 AND
	stevilo_nadzemnih_etaz <= 11 AND 
	STEVILO_STANOVANJ >= 9 AND 
	povrsina >= 300 THEN 'Ozki blok'
	
--globoki blok
	WHEN MBG_ratio > 1.5 AND 
	MBG_sirina >= 19 AND 
	stevilo_nadzemnih_etaz >= 5 AND
	stevilo_nadzemnih_etaz <= 11 AND 
	STEVILO_STANOVANJ >= 9 AND 
	povrsina >= 1000 THEN 'Globoki blok'
	
--kratki blok
	WHEN MBG_ratio > 1.5 AND 
	MBG_sirina >= 12 AND MBG_sirina <= 20 AND
	MBG_dolzina <= 50 AND
	stevilo_nadzemnih_etaz >= 5 AND
	stevilo_nadzemnih_etaz <= 6 AND 
	STEVILO_STANOVANJ >= 15 AND 
	povrsina >= 350 THEN 'Kratki blok'

--nizki blok
	WHEN MBG_ratio > 1.5 AND
	MBG_sirina >= 8 AND 
	stevilo_nadzemnih_etaz >= 3 AND
	stevilo_nadzemnih_etaz <= 5 AND 
	STEVILO_STANOVANJ >= 9 AND 
	povrsina >= 300 THEN 'Nizki blok'

--visoki blok
	WHEN MBG_ratio > 1.5 AND 
	MBG_sirina >= 12 AND 
	stevilo_nadzemnih_etaz >= 10 AND 
	STEVILO_STANOVANJ >= 60 AND 
	povrsina >= 350 THEN 'Visoki blok'

--osnovni blok	
    WHEN MBG_ratio > 1.5 AND 
	MBG_sirina >= 10 AND MBG_sirina <= 25 AND
	stevilo_nadzemnih_etaz >= 4 AND
	stevilo_nadzemnih_etaz <= 11 AND 
	STEVILO_STANOVANJ >= 20 AND 
	povrsina >= 450 THEN 'Osnovni blok'

--večstanovanjska stavba
	WHEN stevilo_nadzemnih_etaz >= 1 AND
	STEVILO_STANOVANJ >= 5 AND STEVILO_STANOVANJ < 10 AND
	povrsina > 150
	OR(STEVILO_STANOVANJ > 10 AND STEVILO_STANOVANJ < 45 AND povrsina > 350)
	OR(stevilo_nadzemnih_etaz >= 3 AND STEVILO_STANOVANJ >= 4 AND povrsina > 350 AND STEVILO_POSLOVNIH_PROSTOROV >=4)
	THEN 'Večstanovanjska stavba'
	
--enodruzinska
	WHEN stevilo_nadzemnih_etaz >= 1 AND
	stevilo_nadzemnih_etaz <= 4 AND
	STEVILO_STANOVANJ >=1 AND
	STEVILO_STANOVANJ <= 6 
	OR(stevilo_nadzemnih_etaz <= 6 AND STEVILO_STANOVANJ <=4)
	OR(stevilo_nadzemnih_etaz IS NULL AND STEVILO_STANOVANJ <=4)
	THEN 'Enodružinska hiša'

	ELSE 'Hibrid'
    END 
WHERE stevilo_prekrivanj = 0;
---------------------------------------------------------
 --N
 -- Klasifikacija povezanih stavb
 WITH cluster_stats AS (
    SELECT
        cluster_id,
        SUM(CASE WHEN komponente = 'krajne_a' THEN 1 ELSE 0 END) AS krajne_a_count,
        SUM(CASE WHEN komponente = 'vmesne_a' THEN 1 ELSE 0 END) AS vmesne_a_count,
        SUM(CASE WHEN komponente = 'vmesne_v' THEN 1 ELSE 0 END) AS vmesne_v_count,
        SUM(CASE WHEN komponente = 'krajne_v' THEN 1 ELSE 0 END) AS krajne_v_count,
        SUM(CASE WHEN komponente = 'dvojcek_blok' THEN 1 ELSE 0 END) AS dvojcek_blok_count,
        AVG(stevilo_nadzemnih_etaz) AS avg_nadzemnih_etaz,
        SUM(MBG_dolzina) AS sum_dolzina,
        SUM(STEVILO_STANOVANJ) AS sum_stevilo_stanovanj,
        AVG(MBG_sirina) AS avg_MBG_sirina,
        SUM(povrsina) AS sum_povrsina,
		COUNT(*) AS total_count
    FROM rezultati.Kataster_stanovanjskih_stavb
    WHERE stevilo_prekrivanj > 0
    GROUP BY cluster_id
),

cluster_categories AS (
    SELECT
        cs.cluster_id,
        CASE
            WHEN cs.krajne_a_count = 4 AND cs.vmesne_a_count >= 2 AND cs.avg_nadzemnih_etaz <= 3 
            OR(cs.vmesne_v_count = cs.total_count AND cs.avg_nadzemnih_etaz <= 3)
			OR(cs.krajne_v_count = 4 AND cs.vmesne_v_count >= 2 AND cs.avg_nadzemnih_etaz <= 3)
			THEN 'Atrijska hiša'
			WHEN cs.vmesne_v_count = cs.total_count AND cs.avg_nadzemnih_etaz >= 3 THEN 'Blok na dvorišče'
            WHEN cs.krajne_v_count = 2 AND cs.vmesne_v_count >= 1 AND cs.avg_nadzemnih_etaz <= 3.5 THEN 'Vrstna hiša'
     		WHEN cs.dvojcek_blok_count = cs.total_count AND cs.avg_nadzemnih_etaz <= 3.5 
			OR(cs.dvojcek_blok_count = cs.total_count AND cs.avg_nadzemnih_etaz <= 5 AND cs.sum_stevilo_stanovanj <=3)THEN 'Dvojček'
	
			WHEN cs.krajne_v_count = 2 AND cs.vmesne_v_count >= 1 AND 
	 		cs.avg_nadzemnih_etaz >= 3 AND
			cs.avg_nadzemnih_etaz <= 5 AND
			cs.avg_MBG_sirina >= 8 AND 
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina >= 300     
	THEN 'Nizki blok'
            
	WHEN cs.krajne_v_count = 2 AND 
			cs.vmesne_v_count >= 1 AND 
			cs.avg_nadzemnih_etaz >= 5 AND
			cs.avg_nadzemnih_etaz <= 6 AND
			cs.avg_MBG_sirina >= 12 AND
			cs.avg_MBG_sirina <= 20 AND
			cs.sum_dolzina <= 50 AND
			cs.sum_stevilo_stanovanj >= 15 AND
			cs.sum_povrsina >= 350   
	THEN 'Kratki blok'
	
            WHEN cs.krajne_v_count = 2 AND 
			cs.vmesne_v_count >= 1 AND 
			cs.avg_nadzemnih_etaz >= 4 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 8 AND 
			cs.avg_MBG_sirina <= 12 AND
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina >= 300
	THEN 'Ozki blok'
	
            WHEN cs.krajne_v_count = 2 AND 
			cs.vmesne_v_count >= 1 AND 
			cs.avg_nadzemnih_etaz >= 5 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 19 AND 
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina>= 1000 
	THEN 'Globoki blok'

	WHEN cs.krajne_v_count = 2 AND 
			cs.vmesne_v_count >= 1 AND 
			cs.avg_nadzemnih_etaz >= 10 AND
			cs.avg_MBG_sirina >= 12 AND 
			cs.sum_stevilo_stanovanj >= 60 AND
			cs.sum_povrsina>= 350 
	THEN 'Visoki blok'

	WHEN cs.krajne_v_count = 2 AND 
			cs.vmesne_v_count >= 1 AND 
			cs.avg_nadzemnih_etaz >= 4 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 10 AND 
			cs.avg_MBG_sirina <= 25 AND
			cs.sum_stevilo_stanovanj >= 20 AND
			cs.sum_povrsina>= 450 
	THEN 'Osnovni blok'

	WHEN cs.dvojcek_blok_count = cs.total_count AND 
	 		cs.avg_nadzemnih_etaz >= 3 AND
			cs.avg_nadzemnih_etaz <= 5 AND
			cs.avg_MBG_sirina >= 8 AND 
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina >= 300     
	THEN 'Nizki blok'
            
	WHEN cs.dvojcek_blok_count = cs.total_count AND 
			cs.avg_nadzemnih_etaz >= 5 AND
			cs.avg_nadzemnih_etaz <= 6 AND
			cs.avg_MBG_sirina >= 12 AND
			cs.avg_MBG_sirina <= 20 AND
			cs.sum_dolzina <= 50 AND
			cs.sum_stevilo_stanovanj >= 15 AND
			cs.sum_povrsina >= 350   
	THEN 'Kratki blok'
	
            WHEN cs.dvojcek_blok_count = cs.total_count AND 
			cs.avg_nadzemnih_etaz >= 4 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 8 AND 
			cs.avg_MBG_sirina <= 12 AND
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina >= 300
	THEN 'Ozki blok'
	
            WHEN cs.dvojcek_blok_count = cs.total_count AND 
			cs.avg_nadzemnih_etaz >= 5 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 19 AND 
			cs.sum_stevilo_stanovanj >= 9 AND
			cs.sum_povrsina>= 1000 
	THEN 'Globoki blok'

	WHEN cs.dvojcek_blok_count = cs.total_count AND 
			cs.avg_nadzemnih_etaz >= 10 AND
			cs.avg_MBG_sirina >= 12 AND 
			cs.sum_stevilo_stanovanj >= 60 AND
			cs.sum_povrsina>= 350 
	THEN 'Visoki blok'

	WHEN cs.dvojcek_blok_count = cs.total_count AND  
			cs.avg_nadzemnih_etaz >= 4 AND
			cs.avg_nadzemnih_etaz <= 11 AND
			cs.avg_MBG_sirina >= 10 AND 
			cs.avg_MBG_sirina <= 25 AND
			cs.sum_stevilo_stanovanj >= 20 AND
			cs.sum_povrsina>= 450 
	THEN 'Osnovni blok'
	
            ELSE 'Hibrid'
        END AS cluster_tipologija
    FROM cluster_stats cs
    JOIN rezultati.Kataster_stanovanjskih_stavb g ON g.cluster_id = cs.cluster_id
	GROUP BY cs.cluster_id, cs.krajne_a_count, cs.vmesne_a_count, cs.vmesne_v_count, cs.krajne_v_count, cs.dvojcek_blok_count, 
	cs.avg_nadzemnih_etaz, cs.sum_dolzina, cs.sum_stevilo_stanovanj, cs.avg_MBG_sirina, cs.sum_povrsina, cs.total_count
)
UPDATE rezultati.Kataster_stanovanjskih_stavb
SET tipologija = cc.cluster_tipologija
FROM cluster_categories cc
WHERE rezultati.Kataster_stanovanjskih_stavb.cluster_id = cc.cluster_id;
-----------------------------------------------------------------------------------
-- O
-- Klasifikacija tipologija na vzorec zazidave
ALTER TABLE rezultati.Kataster_stanovanjskih_stavb
ADD COLUMN IF NOT EXISTS vzorec_zazidave TEXT;

UPDATE rezultati.Kataster_stanovanjskih_stavb
SET vzorec_zazidave = 
CASE
    WHEN tipologija = 'Globoki blok' THEN 'linijski vzorec zazidave'
    WHEN tipologija = 'Ozki blok' THEN 'linijski vzorec zazidave'
    WHEN tipologija = 'Stolpič' THEN 'točkovni vzorec zazidave'
    WHEN tipologija = 'Stolpnica' THEN 'točkovni vzorec zazidave'
    WHEN tipologija = 'Vila blok' THEN 'točkovni vzorec zazidave'
    WHEN tipologija = 'Enodružinska hiša' THEN 'točkovni vzorec zazidave'
    WHEN tipologija = 'Dvojček' THEN 'točkovni vzorec zazidave'
    WHEN tipologija = 'Atrijska hiša' THEN 'mrežni vzorec zazidave'
    WHEN tipologija = 'Blok na dvorišče' THEN 'mrežni vzorec zazidave'
    WHEN tipologija = 'Večstanovanjska stavba' THEN NULL
    WHEN tipologija = 'Vrstna hiša' THEN 'linijski vzorec zazidave'
	WHEN tipologija = 'Nizki blok' THEN 'linijski vzorec zazidave'
	WHEN tipologija = 'Kratki blok' THEN 'linijski vzorec zazidave'
	WHEN tipologija = 'Visoki blok' THEN 'linijski vzorec zazidave'
	WHEN tipologija = 'Osnovni blok' THEN 'linijski vzorec zazidave'
    ELSE NULL
END;
--------------------------------------------------------
-- P
-- Priprava lookup tabele za nadometne tipologije (za ročni pregled)
DROP TABLE IF EXISTS rezultati.NADOMESTNA_TIPOLOGIJA;

CREATE TABLE IF NOT EXISTS rezultati.NADOMESTNA_TIPOLOGIJA (
	GID SERIAL PRIMARY KEY,
	NADOMESTNA_TIPOLOGIJA TEXT
);

INSERT INTO
	rezultati.NADOMESTNA_TIPOLOGIJA (NADOMESTNA_TIPOLOGIJA)
VALUES
	('Globoki blok'),
	('Ozki blok'),
	('Stolpič'),
	('Stolpnica'),
	('Vila blok'),
	('Enodružinska hiša'),
	('Dvojček'),
	('Atrijska hiša'),
	('Blok na dvorišče'),
	('Večstanovanjska stavba'),
	('Vrstna hiša'),
	('Nizki blok'),
	('Kratki blok'),
	('Visoki blok'),
	('Osnovni blok'),
	('Hibrid');








	