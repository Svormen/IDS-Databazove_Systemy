drop table cestujuci cascade constraints;
drop table letenka cascade constraints;
drop table sedadlo cascade constraints ;
drop table let cascade constraints;
drop table gate cascade constraints ;
drop table terminal cascade constraints;
drop table lietadlo cascade constraints ;
drop table clen_posadky cascade constraints ;
drop table lietadlo_posadka cascade constraints;
drop table typ cascade constraints;
drop table typ_vyrobca cascade constraints;
drop table vyrobca cascade constraints ;
drop sequence cest_id;

create table cestujuci (
    cestujuci_id number not null primary key,
    cestujuci_meno varchar2(50) not null ,
    cestujuci_priezvisko varchar(50) not null,
    cestujuci_datum date not null
);

create table sedadlo (
    sedadlo_cislo number(2) not null primary key,
    sedadlo_trieda char(10) not null,
    sedadlo_miesto char(10) not null
    check ( REGEXP_LIKE(sedadlo_miesto, '^window|isle|middle')),
    check ( REGEXP_LIKE(sedadlo_trieda, '^first|economy|business'))
);

create table terminal(
    terminal_nazov char(1) not null primary key
    check ( REGEXP_LIKE(terminal_nazov, '^[a-z]'))
);

create table gate(
    gate_cislo number generated always as identity primary key,

    terminal_nazov char(1) not null,
    constraint gate_terminal
                     foreign key (terminal_nazov)
                     references terminal(terminal_nazov)
);

create table clen_posadky(
    clen_posadky_id number(2) not null primary key
);

create table typ(
    typ_id number generated always as identity primary key,
    typ_nazov varchar2(10) not null,
    typ_typ varchar2(10) not null,
    typ_pocet_miest number(3),
    typ_nosnost number(4),
    check ( REGEXP_LIKE(typ_typ, '^osobne|nakladne')),
    check ( REGEXP_LIKE(typ_nazov, '^boeing|airbus'))
);

create table vyrobca(
    vyrobca_id varchar2(8) not null primary key,
    check ( REGEXP_LIKE(vyrobca_id, '^[0-9]{8}$'))  --IČO
);

create table typ_vyrobca(
    typ_vyrobca_id number generated always as identity primary key,
    typ_id number not null,
    vyrobca_id varchar2(8) not null,
    constraint typ_vyrobca_typ_id
                     foreign key (typ_id)
                     references typ(typ_id),
    constraint typ_vyrobca_vyrobca_id
                     foreign key (vyrobca_id)
                     references vyrobca(vyrobca_id)
);

create table lietadlo(
    lietadlo_cislo number generated always as identity primary key,
    lietadlo_datum_revizie date not null,
    lietadlo_datum_vyroby date not null,

    gate_cislo number not null,
    typ_id number not null,
    constraint lietadlo_gate
                     foreign key (gate_cislo)
                     references gate(gate_cislo),
    constraint lietadlo_typ
                     foreign key (typ_id)
                     references typ(typ_id)
);

create table lietadlo_posadka(
    lietadlo_posadka_id number generated always as identity primary key,
    lietadlo_cislo number not null,
    clen_posadky_id number not null unique,
    constraint lietadlo_posadka_lietadlo_cislo
                     foreign key (lietadlo_cislo)
                     references lietadlo(lietadlo_cislo),
    constraint lietadlo_posadka_clen_posadky_id
                     foreign key (clen_posadky_id)
                     references clen_posadky(clen_posadky_id)
);

create table let (
    let_cislo char(6) not null primary key,
    let_cas_odletu timestamp not null,
    let_dlzka number(3) not null,   --dlzka letu v minutach

    gate_cislo number not null,
    lietadlo_cislo number not null,
    constraint let_lietadlo
                     foreign key (lietadlo_cislo)
                     references lietadlo(lietadlo_cislo),
    constraint let_gate
                     foreign key (gate_cislo)
                     references gate(gate_cislo),

    check ( REGEXP_LIKE(let_cislo, '^[A-Z]{3}[0-9]{3}'))
);

create table letenka (
    letenka_id number generated always as identity primary key,
    letenka_batozina number(2) not null,        -- batožina kilogramy

    let_cislo char(6) not null,
    sedadlo_cislo number(2) not null unique,
    cestujuci_id number not null unique,
    constraint letenka_cestujuci
                     foreign key (cestujuci_id)
                     references cestujuci(cestujuci_id),
    constraint letenka_sedadlo
                     foreign key (sedadlo_cislo)
                     references sedadlo(sedadlo_cislo),
    constraint letenka_let
                     foreign key (let_cislo)
                     references let(let_cislo)
);

-- TRIGGERY
-- Trigger pre generovanie ID cestujuceho
CREATE SEQUENCE cest_id;
CREATE OR REPLACE TRIGGER generate_cest_id BEFORE
    INSERT ON cestujuci
    FOR EACH ROW
    WHEN ( new.cestujuci_id IS NULL )
BEGIN
    :new.cestujuci_id := cest_id.nextval;
END;
/

-- Trigger pre kontrolu hmotnosti batožiny v zavislosti na triede v ktorej cestujuci sedí
CREATE OR REPLACE TRIGGER kontrola_batoziny BEFORE
    INSERT OR UPDATE OF letenka_batozina ON letenka
    FOR EACH ROW
DECLARE
    trieda char(10);
BEGIN
    SELECT sedadlo_trieda
    INTO trieda
    FROM sedadlo
    WHERE
          sedadlo_cislo = :new.sedadlo_cislo;

    IF (trieda = 'first' and  :new.letenka_batozina > 30) THEN
        raise_application_error(-20222,'Presiahli ste hmotnosť batožiny');
    end if;

    IF (trieda = 'business' and  :new.letenka_batozina > 25) THEN
        raise_application_error(-20222,'Presiahli ste hmotnosť batožiny');
    end if;

    IF (trieda = 'economy' and  :new.letenka_batozina > 20) THEN
        raise_application_error(-20222,'Presiahli ste hmotnosť batožiny');
    end if;

    -- NEFUNGUJE MI ELSEIF V DATAGRIPE, TAK JE TO TAKTO POIFOVANE
END;
/

-- PROCEDURY

-- Procedura vypiše všetky lietadla ktore potrebuju prejsť reviziou ak od poslednej revizie uplynulo viac ako 5 rokov
CREATE OR REPLACE PROCEDURE potrebna_revizia IS
    liet_c lietadlo.lietadlo_cislo%TYPE;
    liet_rev lietadlo.lietadlo_datum_revizie%TYPE;
    rozdiel number;
    CURSOR curs_lietadlo IS SELECT
        lietadlo_cislo , lietadlo_datum_revizie
                     FROM
        lietadlo;
BEGIN
     OPEN curs_lietadlo;

      LOOP
        FETCH curs_lietadlo INTO liet_c, liet_rev;
        EXIT WHEN curs_lietadlo%notfound;
        IF
            ((current_date - liet_rev) > 1825)
        THEN
            dbms_output.put_line('Lietadlo s ID ' || liet_c || ' potrebuje reviziu. Už uplynulo viac ako 5 rokov od poslednej revízie.');
        END IF;
    END LOOP;
END;
/

-- Procedura vypiše počet lietadiel v databaze, počet osobnych lietadiel a vyrata percentualne zastupenie osobnych lietadiel
CREATE OR REPLACE PROCEDURE pocet_pasazierov IS
   typ_liet typ.typ_typ%TYPE;
   typ_liet_id typ.typ_id%TYPE;
   pocet_osobnych number;
   pocet_celkovo number;
   CURSOR curs_lietadlo IS SELECT
        typ_id
            FROM
        lietadlo;
BEGIN
    OPEN curs_lietadlo;
    pocet_osobnych := 0;
    SELECT
        COUNT(*)
    INTO
        pocet_celkovo
    FROM
        lietadlo;
    LOOP
        FETCH curs_lietadlo INTO typ_liet_id;
        EXIT WHEN curs_lietadlo%notfound;

        SELECT typ_typ
        INTO
            typ_liet
        FROM typ
        WHERE
              typ_liet_id = typ.typ_id;

        IF
            (typ_liet = 'osobne')
        THEN
            pocet_osobnych := pocet_osobnych + 1;
        END IF;

    END LOOP;
    dbms_output.put_line('Pocet vsetkych lietadiel v systeme: ' || pocet_celkovo || ' Pocet osobnych lietadiel: ' || pocet_osobnych);
    dbms_output.put_line('Percentualne zastupenie osobnych lietadiel: ' || ROUND(pocet_osobnych / pocet_celkovo * 100, 2) || ' %');

    EXCEPTION
    WHEN ZERO_DIVIDE THEN
        dbms_output.put_line('Žiadne osobne lietadla sa v databaze nenachadzaju.');
end;
/


insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('John', 'Parking', date '1958-02-04');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Caren', 'Storek', date '1977-06-09');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Alojz', 'Halv', date '1998-06-09');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Fred', 'Call', date '2005-06-09');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Lona', 'Raly', date '1995-06-25');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Lambda', 'Alfa', date '2010-08-08');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Luk', 'Skyrel', date '1958-02-02');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Laren', 'Fero', date '1974-09-12');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Juster', 'Nalek', date '1974-09-28');

insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (7, 'first', 'window');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (77, 'business', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (99, 'economy', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (50, 'first', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (51, 'economy', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (52, 'economy', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (53, 'business', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (54, 'economy', 'isle');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (55, 'economy', 'isle');


insert into terminal (terminal_nazov)
values ('a');
insert into terminal (terminal_nazov)
values ('b');

insert into gate (terminal_nazov)
values ('a');
insert into gate (terminal_nazov)
values ('b');

insert into vyrobca (vyrobca_id)
values ('19874583');
insert into vyrobca (vyrobca_id)
values ('21578964');

insert into typ (typ_nazov, typ_typ, typ_pocet_miest, typ_nosnost)
values ('boeing', 'osobne', 180, 7000);
insert into typ (typ_nazov, typ_typ, typ_pocet_miest, typ_nosnost)
values ('airbus', 'osobne', 200, 6500);
insert into typ (typ_nazov, typ_typ, typ_nosnost)
values ('airbus', 'nakladne', 9800);

insert into typ_vyrobca (typ_id, vyrobca_id)
values (1, '19874583');
insert into typ_vyrobca (typ_id, vyrobca_id)
values (2, '21578964');

insert into lietadlo (lietadlo_datum_revizie, lietadlo_datum_vyroby, gate_cislo, typ_id)
values (date '2010-10-10', date '1987-12-08', 1, 1);
insert into lietadlo (lietadlo_datum_revizie, lietadlo_datum_vyroby, gate_cislo, typ_id)
values (date '2015-04-25', date '2001-11-07', 2, 2);
insert into lietadlo (lietadlo_datum_revizie, lietadlo_datum_vyroby, gate_cislo, typ_id)
values (date '2012-04-25', date '2000-11-07', 2, 3);

insert into clen_posadky (clen_posadky_id)
values (1);
insert into clen_posadky (clen_posadky_id)
values (2);
insert into clen_posadky (clen_posadky_id)
values (3);
insert into clen_posadky (clen_posadky_id)
values (4);

insert into lietadlo_posadka (lietadlo_cislo, clen_posadky_id)
values (1,1);
insert into lietadlo_posadka (lietadlo_cislo, clen_posadky_id)
values (1,2);
insert into lietadlo_posadka (lietadlo_cislo, clen_posadky_id)
values (2,3);
insert into lietadlo_posadka (lietadlo_cislo, clen_posadky_id)
values (2,4);

insert into let (let_cislo, let_cas_odletu, let_dlzka, gate_cislo, lietadlo_cislo)
values ('TVS154', timestamp '2021-05-05 05:00:00', '150', 1, 1);
insert into let (let_cislo, let_cas_odletu, let_dlzka, gate_cislo, lietadlo_cislo)
values ('DHL587', timestamp '2021-09-09 08:15:00', 420, 2, 2);

insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (25,'TVS154', 7, 1);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (22,'TVS154', 77, 2);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'DHL587', 99, 3);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'TVS154', 50, 4);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'DHL587', 51, 5);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'TVS154', 52, 6);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'TVS154', 53, 7);
insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (18,'DHL587', 54, 8);

/* SELECT - spojenie 3 tabuliek -> dotaz vyberie vsetkych cestujuich medzi vsetkymi letmi, ktorych batozina presiahla 20 kg */
SELECT let_cislo,
       cestujuci_meno,
       cestujuci_priezvisko
FROM
     cestujuci
    NATURAL JOIN letenka
    NATURAL JOIN let
WHERE
    letenka_batozina > 20;

/* SELECT - spojenie 2 tabuliek -> dotaz vyberie vsetky lietadla typu boeing a vrati ich datum vyroby a revizie */
SELECT lietadlo_datum_vyroby,
       lietadlo_datum_revizie
FROM
    typ
    NATURAL JOIN lietadlo
WHERE
    typ_nazov = 'boeing';

/* SELECT - spojenie 2 tabuliek -> dotaz vrati vsetky lety (ich cislo, cas odletu, dlzku letu) z daneho gate-u */
SELECT let_cislo,
       let_cas_odletu,
       let_dlzka
FROM
    gate
    NATURAL JOIN let
WHERE
    gate_cislo = 1;

/* SELECT - dotaz s klauzulou GROUP BY + agregacna fc -> dotaz vypise cislo letu a ukaze jeho celkovu hmotnost batozin  */
SELECT let_cislo,
        SUM(letenka_batozina) celkova_hmotnost_batozin
FROM
    letenka
    NATURAL JOIN let
GROUP BY let_cislo;

/* SELECT - dotaz s klauzulou GROUP BY + agregacna fc -> dotaz vypise cislo letu a pocet ludi, ktori sedia v prvej triede v danom lete */
SELECT let_cislo,
       COUNT(sedadlo_trieda) pocet_prvych_tried
FROM
     sedadlo
     NATURAL JOIN letenka
     NATURAL JOIN let
HAVING
    sedadlo_trieda = 'first'
GROUP BY sedadlo_trieda, let_cislo;

/* SELECT - dotaz s vyuzitim EXISTS -> dotaz vrati cisla letov, ktore lietaju lietadlom nie starsim ako 36 rokov */
SELECT let_cislo
FROM
     let
WHERE
    EXISTS
        (
            SELECT  lietadlo_cislo
            FROM
                lietadlo
            WHERE
                let.lietadlo_cislo = lietadlo.lietadlo_cislo and lietadlo_datum_vyroby > date '1985-04-18'
        );


/* SELECT - dotaz s vyuzitim IN -> dotaz vrati mena cestujucich, ktorí sedia v ptvej triede a maju batozinu tazsiu ako 20kg */
SELECT
    cestujuci_meno,
    cestujuci_priezvisko
FROM
    cestujuci
WHERE
    cestujuci_id
    IN
    (
        SELECT cestujuci_id
        FROM
            letenka
            NATURAL JOIN sedadlo
        WHERE
            letenka_batozina > 20 and sedadlo_trieda = 'first'
    );

-- 4 PROJEKT

-- volanie procedur
BEGIN potrebna_revizia; END;
BEGIN pocet_pasazierov; END;

-- UKAZKOVY INSERT KTORY SPADNE NA TRIGGERY

/*insert into letenka (letenka_batozina, let_cislo, sedadlo_cislo, cestujuci_id)
values (40,'DHL587', 55, 9);*/

-- EXPLAIN PLAN
-- Select pre explain plan vypise vsetky lety v databazi a ku každemu vypise kolko je obsadenych prvych tried, economy tried a business tried

-- EXPLAN PLAN bez použita indexu
EXPLAIN PLAN FOR
SELECT let_cislo,
       COUNT(CASE sedadlo_trieda WHEN 'first' THEN 1 ELSE NULL END) as first,
       COUNT(CASE sedadlo_trieda WHEN 'business' THEN 1 ELSE NULL END) as business,
       COUNT(CASE sedadlo_trieda WHEN 'economy' THEN 1 ELSE NULL END) as economy
FROM
    letenka
    natural join sedadlo
GROUP BY let_cislo;
-- OUTPUT pre explain plan
SELECT * FROM TABLE(dbms_xplan.display);


-- Pridanie práv pre druheho člena tímu
GRANT ALL ON cestujuci TO XSVORA02;
GRANT ALL ON sedadlo TO XSVORA02;
GRANT ALL ON terminal TO XSVORA02;
GRANT ALL ON gate TO XSVORA02;
GRANT ALL ON clen_posadky TO XSVORA02;
GRANT ALL ON typ TO XSVORA02;
GRANT ALL ON vyrobca TO XSVORA02;
GRANT ALL ON typ_vyrobca TO XSVORA02;
GRANT ALL ON lietadlo TO XSVORA02;
GRANT ALL ON lietadlo_posadka TO XSVORA02;
GRANT ALL ON let TO XSVORA02;
GRANT ALL ON letenka TO XSVORA02;

GRANT EXECUTE ON potrebna_revizia TO XSVORA02;
GRANT EXECUTE ON pocet_pasazierov TO XSVORA02;

-- Vytvorenie materialized view
CREATE MATERIALIZED VIEW vypis_osob AS
    SELECT *
    FROM cestujuci;

-- priradenie prav na materialized view pre druheho clena timu
GRANT ALL ON vypis_osob TO XSVORA02;

-- vypis materializovaneho pohladu
SELECT * from vypis_osob;

-- pridanie hodnoty do tabulky s cestujucimi
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Skuska', 'Pohladu', date '1988-09-12');


-- opatovne volanie vypisu pohladu pre demonstraciu materialozovaneho pohladu - stale rovnaky
SELECT * from vypis_osob;

DROP MATERIALIZED VIEW vypis_osob;

-- Vytvorenie indexu
CREATE INDEX explan_ind ON sedadlo (sedadlo_cislo, sedadlo_trieda);

-- EXPLAIN PLAN s pouzitim indexu
EXPLAIN PLAN FOR
SELECT let_cislo,
       COUNT(CASE sedadlo_trieda WHEN 'first' THEN 1 ELSE NULL END) as first,
       COUNT(CASE sedadlo_trieda WHEN 'business' THEN 1 ELSE NULL END) as business,
       COUNT(CASE sedadlo_trieda WHEN 'economy' THEN 1 ELSE NULL END) as economy
FROM
    letenka
    natural join sedadlo
GROUP BY let_cislo;

-- OUTPUT pre explain plan s indexom
SELECT * FROM TABLE(dbms_xplan.display);

-- Dropnutie indexu
DROP INDEX explan_ind;

-- Samotny select pri explain plane
SELECT let_cislo,
       COUNT(CASE sedadlo_trieda WHEN 'first' THEN 1 ELSE NULL END) as first,
       COUNT(CASE sedadlo_trieda WHEN 'business' THEN 1 ELSE NULL END) as business,
       COUNT(CASE sedadlo_trieda WHEN 'economy' THEN 1 ELSE NULL END) as economy
FROM
    letenka
    natural join sedadlo
GROUP BY let_cislo;



/*select * from cestujuci;
select * from sedadlo;
select * from terminal;
select * from gate;
select * from vyrobca;
select * from typ;
select * from typ_vyrobca;
select * from lietadlo;
select * from clen_posadky;
select * from lietadlo_posadka;
select * from let;
select * from letenka;*/