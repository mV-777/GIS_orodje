# GIS analitično orodje za klasifikacijo tipologij stanovanjskih stavb

To orodje je rezultat magistrske naloge, ki se osredotoča na razvoj GIS orodja za avtomatizirano klasifikacijo tipologij stanovanjskih stavb v Sloveniji. Glavni namen je reševanje pomanjkanja enotne evidence o stavbnih tipologijah, kar predstavlja oviro za učinkovito analizo in vrednotenje prostorskih podatkov.

## Ključne funkcionalnosti
- Morfološka analiza stavb: Orodje uporablja podatke iz katastra nepremičnin in vnaprej določena pravila za avtomatizirano razvrščanje stavb.
- Klasifikacija stavb: Stavbe razvršča na prostostoječe in povezane, z nadaljnjo delitvijo glede na tipologijo in vzorec zazidave.
- Podpora uporabnikom: Raziskava vključuje priročnik, ki jasno povezuje teoretične koncepte z implementacijo orodja.

## Namen in cilji
Raziskava je namenjena izboljšanju sistematičnega evidentiranja stavbnih tipologij v Sloveniji, s ciljem prispevati k:
- učinkovitejšemu prostorskemu načrtovanju,
- trajnostnemu razvoju urbanih območij,
- vzpostavitvi natančne evidence stavb, ki podpira nadaljnje raziskave in nadgradnje prostorskih podatkov.

## Pomen
Razvito orodje predstavlja pomemben korak k modernizaciji analize prostorskih podatkov v Sloveniji. Njegova zasnova omogoča enostavno prilagajanje in nadgradnjo za širšo uporabo v različnih prostorskih raziskavah.

Za več informacij in dostop do orodja obiščite [objavo na Repozitoriju Univeze v Ljubljani](https://repozitorij.uni-lj.si/IzpisGradiva.php?id=164021&lang=slv).



# Priprava programskih orodji ter uvoz podatkov in orodja


## Navodila za namestitev programskih orodji
1. Namestitev PostgreSQL
Obiščite uradno spletno stran PostgreSQL in prenesite najnovejšo različico, primerno za vaš operacijski sistem. Zaženite preneseni namestitveni program in sledite korakom namestitvenega čarovnika. Priporočljivo je, da ohranite privzete nastavitve, razen če imate specifične zahteve. Med namestitvijo boste morali nastaviti geslo za privzeti uporabniški račun postgres. Priporočljivo je, da izberete močno geslo in ga zabeležite, saj ga boste potrebovali za dostop do baze. Po zaključku namestitve se bo odprl StackBuilder, ki omogoča namestitev dodatnih razširitev. Izberite namestitev PostgreSQL in nadaljujte z namestitvijo.

2. Namestitev PostGIS (razširitev za prostorske podatke)
Ko StackBuilder zazna vašo namestitev PostgreSQL, izberite razširitev PostGIS pod zavihkom “Spatial Extensions”. Izberite najnovejšo različico PostGIS in sledite navodilom za namestitev. Pri PostGISBundle pokljukajte vse komponente. Povežite se na svojo PostgreSQL bazo z geslom in podajte ime svoji bazi (v našem primeru bomo dali test). Po uspešni namestitvi odprite PgAdmin in se prijavite v svojo PostgreSQL bazo podatkov z uporabniškim imenom postgres in geslom, ki ste ga nastavili med namestitvijo PostgreSQL.
Koristna povezava za nastavitev PostGIS:
https://postgis.net/documentation/getting_started/

3. Namestitev PgAdmin
Po namestitvi PostGIS, odprite PgAdmin, vnesite uporabniško ime postgres in geslo, ki ste ga nastavili med namestitvijo PostgreSQL, ter se povežite na lokalno bazo podatkov. Tukaj lahko upravljate svoje baze, izvajate SQL poizvedbe in spremljate delovanje PostgreSQL sistema. Za potrebe analize je v PgAdminu potrebno nastaviti razširitve za PostGIS. Da nastavite razširitve za PostGIS, sledite spodnjim korakom:
Odprite PgAdmin, poiščite in izberite bazo podatkov test, kjer želite nastaviti razširitve. Desni klik na bazo podatkov test in izberite Query Tool (Orodje za poizvedbe).
V oknu za poizvedbe vpišite naslednji SQL ukaz za nastavitev PostGIS razširitev:
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_sfcgal;
Pritisnite F5 ali kliknite gumb Execute (Zaženi) v orodni vrstici, da poizvedbo zaženete.
Po uspešni izvedbi poizvedbe boste v spodnjem delu okna prejeli potrdilo o uspešni namestitvi razširitev.

4. Namestitev QGIS
Obiščite uradno spletno stran QGIS in prenesite najnovejšo stabilno različico, združljivo z vašim operacijskim sistemom. Zaženite namestitveni program in sledite korakom namestitvenega čarovnika. QGIS privzeto namesti vse potrebne knjižnice za delo s prostorskimi podatki. Po namestitvi QGIS-a, sledite tem korakom, da ga povežete s svojo PostgreSQL/PostGIS bazo podatkov:
V QGIS v meniju Browser poiščite PostgreSQL. Desni klik na PostgreSQL in izberite New Connection (nova povezava).
V oknu za povezavo vnesite naslednje podatke:
Name: ime povezave (predlagamo isto ime kot za bazo - test)<br/>
Host: localhost<br/>
Port: 5432<br/>
Database: ime vaše baze (test)<br/>
Kliknite na Test Connection, da preverite povezavo, nato vnesite:<br/>
Username: postgres
Password: geslo, ki ste ga nastavili med namestitvijo PostgreSQL.
Če je povezava uspešna, boste prejeli obvestilo o uspešni povezavi.
Nastavite dodatne možnosti:
Odkljukajte Also list tables with no geometry in Allow saving/loading QGIS projects in the database.
Kliknite OK, da potrdite povezavo.
Koristna povezava za integracijo PostGIS v QGIS:
https://www.line-45.com/post/using-qgis-postgis-dynamic-duo

S temi koraki ste uspešno namestili in povezali PostgreSQL, PostGIS in QGIS za delo z
geografsko-prostorskimi podatki. Naslednji korak je vnos potrebnih podatkov o stavbah in
GIS analitičneg orodja za klasifikacijo stanovanjskih stavb.

## Vnos podatkov in GIS analitičneg orodja
Podatki in orodje bodo objavljeni skupaj z nalogo na repozitoriju Univerze v Ljubljani, kjer bodo dostopne naslednje mape:
- Mapa PODATKI vsebuje mapo RESTORE z direktorijem podatkov in schem, potrebnih za delovanje orodja, ter navodila za obnovitev (restore) direktorija.
- Mapa GIS ORODJE vključuje SQL poizvedbo in mapo s petimi modeli analitičnih sklopov.
- Mapa ŠTUDIJA PRIMERA vsebuje geopackage (rezultati.gpkg) z vsemi rezultati študije primera.
- Mapa PRIROČNIK vsebuje PDF različico magistrske naloge, ki služi kot vodnik za uporabo orodja.
- Poleg tega je priložen še QGIS projekt (project_template.qgz), ki je prazen, vendar že vsebuje nastavljeno orodje. Ta projekt je namenjen uporabi pri lastnih študijah.

Vnos podatkov v bazo:
V orodju **PgAdmin** izberite ustvarjeno bazo podatkov (test), kamor želite uvoziti pripravljene podatke.
Z desnim klikom na bazo izberite **Restore**.
V zavihku _General_ za _Format_ izberete Directory, nato poiščite mapo RESTORE v polju _Filename_.
V zavihku _Data Options_ odkljukajte možnosti Owner in Privileges.
V zavihku Query Options odkljukajte možnosti Clean Before Restore in Include If Exists Clause.
V zavihku Table Options pustite privzete nastavitve.
V zavihku Options odkljukajte možnost Triggers.
Na koncu kliknite Restore. Po nekaj minutah boste prejeli obvestilo o uspešnosti vnosa podatkov.
Koristna povezava za uvoz baze podatkov v PgAdmin:
https://www.pgadmin.org/docs/pgadmin4/development/restore_dialog.html

Z uspešnim uvozom podatkov je orodje pripravljeno za uporabo.


## Uvoz orodja v QGIS
Orodja ni potrebno uvoziti. V QGIS projektu **“project_template”** je orodje že nastavljeno v _Processing Toolbox_ pod _Project model_ - “GIS ORODJE”.
