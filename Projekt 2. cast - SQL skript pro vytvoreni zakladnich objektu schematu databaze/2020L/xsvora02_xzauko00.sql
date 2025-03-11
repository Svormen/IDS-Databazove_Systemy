/*
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
*/

create table cestujuci (
    cestujuci_id number generated always as identity primary key,
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
    check ( REGEXP_LIKE(vyrobca_id, '^[0-9]{8}$'))  --IÈO
);

create table typ_vyrobca(
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

insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('John', 'Parking', date '1999-02-04');
insert into cestujuci (cestujuci_meno, cestujuci_priezvisko, cestujuci_datum)
values ('Caren', 'Storek', date '1977-06-09');

insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (7, 'first', 'window');
insert into sedadlo (sedadlo_cislo, sedadlo_trieda, sedadlo_miesto)
values (77, 'business', 'isle');

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
insert into typ (typ_nazov, typ_typ, typ_nosnost)
values ('airbus', 'nakladne', 9800);

insert into typ_vyrobca (typ_id, vyrobca_id)
values (1, '19874583');
insert into typ_vyrobca (typ_id, vyrobca_id)
values (2, '21578964');

insert into lietadlo (lietadlo_datum_revizie, lietadlo_datum_vyroby, gate_cislo, typ_id)
values (date '2010-10-10', date '1987-12-08', 1, 1);
insert into lietadlo (lietadlo_datum_revizie, lietadlo_datum_vyroby, gate_cislo, typ_id)
values (date '2018-09-09', date '2001-11-07', 2, 2);

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
values (18,'TVS154', 77, 2);


/*
select * from cestujuci;
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
select * from letenka;
*/