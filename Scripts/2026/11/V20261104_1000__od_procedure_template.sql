-- ============================================================================
-- Precificacao (schema od): catalogo de referencia de procedimentos.
--
-- Catalogo GLOBAL (nao depende de empresa, como ad.screen) com os
-- procedimentos da planilha de precificacao da clinica, por especialidade:
-- codigo, nome, tempo, material informado, laboratorio e valor de referencia.
-- Alimenta o auto complete do cadastro de procedimento (ad.procedure_suggest):
-- ao digitar o nome, o app sugere os procedimentos do catalogo da especialidade
-- que a filial ainda nao cadastrou e preenche os campos.
--
-- A especialidade e casada pelo NOME (sem diferenciar maiusculas) com
-- od.specialty da filial. Leitura so pela RPC (RLS ligada, sem policy);
-- escrita so por migration (seed abaixo, gerado da planilha
-- PLANILHA_PRECIFICACAO_reconstruida.xlsx; Endodontia = codigos 4.x).
-- ============================================================================

create table od.procedure_template (
  nr_template         bigint         generated always as identity,
  vc_specialty        varchar(40)    not null,
  vc_code             varchar(10),
  vc_name             varchar(80)    not null,
  qt_minutes          numeric(7,2)   not null default 0,
  vl_material_other   numeric(12,2)  not null default 0,
  vl_lab_cost         numeric(12,2)  not null default 0,
  vl_reference_price  numeric(12,2),
  nr_order            integer        not null default 0,
  it_status           smallint       not null default 1,
  nr_operator         bigint,
  dh_created          timestamptz    not null default now(),
  dh_updated          timestamptz    not null default now(),
  constraint procedure_template_pk primary key (nr_template),
  constraint procedure_template_vc_name_check   check (length(trim(vc_name)) > 0),
  constraint procedure_template_qt_minutes_check check (qt_minutes >= 0),
  constraint procedure_template_values_check    check (vl_material_other >= 0 and vl_lab_cost >= 0
                                                   and (vl_reference_price is null or vl_reference_price >= 0)),
  constraint procedure_template_it_status_check check (it_status in (1, 90))
);

create unique index procedure_template_name_uk on od.procedure_template (lower(vc_specialty), lower(vc_name));

alter table od.procedure_template enable row level security;

insert into od.procedure_template
  (vc_specialty, vc_code, vc_name, qt_minutes, vl_material_other, vl_lab_cost, vl_reference_price, nr_order)
values
  ('Clínica Geral', '1.0', 'PROFILAXIA', 60, 2, 0, 150, 10),
  ('Clínica Geral', '2.0', 'CLAREAMENTO LASER (1 SESSÃO)', 90, 63, 0, 700, 20),
  ('Clínica Geral', '2.1', 'CLAREAMENTO LASER (2 SESSÕES)', 180, 126, 0, 1200, 30),
  ('Clínica Geral', '2.2', 'CLAREAMENTO LASER (SESSÃO AVULSA)', 90, 63, 0, 700, 40),
  ('Clínica Geral', '2.3', 'CLAREAMENTO CASEIRO (2 SERINGAS)', 60, 70, 0, 650, 50),
  ('Clínica Geral', '2.4', 'SERINGA AVULSA CLAREADOR', 0, 20, 0, 350, 60),
  ('Clínica Geral', null, 'CLAREAMENTO INTERNO UNITÁRIO', 90, 20, 0, null, 70),
  ('Clínica Geral', '3.0', 'RESTAURAÇÃO SIMPLES 1 FACE', 60, 30, 0, null, 80),
  ('Clínica Geral', '3.1', 'RESTAURAÇÃO SIMPLES 2 FACES', 60, 40, 0, null, 90),
  ('Clínica Geral', '3.2', 'RESTAURAÇÃO SIMPLES 3 FACES', 60, 50, 0, null, 100),
  ('Clínica Geral', '3.3', 'RESTAURAÇÃO EM RESINA COM PINO FIBRA DE VIDRO', 120, 150, 0, null, 110),
  ('Clínica Geral', '3.4', 'RESTAURAÇÃO ESTÉTICA / FACETA', 120, 34.49, 0, null, 120),
  ('Clínica Geral', '3.5', 'BIOBASE', 120, 45.25, 0, null, 130),
  ('Clínica Geral', '3.6', 'PEÇA EM RESINA TÉCNICA DIRETA INDIRETA', 120, 41.38, 0, null, 140),
  ('Endodontia', '4.0', 'TRATAMENTO ENDODÔNTICO UNIRRADICULAR', 90, 120, 0, null, 150),
  ('Endodontia', '4.1', 'TRATAMENTO ENDODÔNTICO BIRRADICULAR', 90, 130, 0, null, 160),
  ('Endodontia', '4.2', 'TRATAMENTO ENDODÔNTICO MOLAR', 120, 150, 0, null, 170),
  ('Endodontia', '4.3', 'RETRATAMENTO ENDODÔNTICO UNIRRADICULAR', 90, 130, 0, null, 180),
  ('Endodontia', '4.4', 'RETRATAMENTO ENDODÔNTICO BIRRADICULAR', 90, 140, 0, null, 190),
  ('Endodontia', '4.5', 'RETRATAMENTO ENDODÔNTICO MOLAR', 180, 160, 0, null, 200),
  ('Clínica Geral', '5.0', 'EXTRAÇÃO RAIZ RESIDUAL', 90, 60, 0, null, 210),
  ('Clínica Geral', '5.1', 'EXTRAÇÃO SIMPLES', 90, 60, 0, null, 220),
  ('Clínica Geral', '5.2', 'EXTRAÇÃO A RETALHO', 120, 80, 0, null, 230),
  ('Clínica Geral', '5.3', 'EXTRAÇÃO DE SUPRANUMERÁRIO', 120, 80, 0, null, 240),
  ('Clínica Geral', '5.4', 'EXTRAÇÃO TERCEIRO MOLAR SIMPLES', 120, 60, 0, null, 250),
  ('Clínica Geral', '5.5', 'EXTRAÇÃO TERCEIRO MOLAR INCLUSO', 120, 80, 0, null, 260),
  ('Clínica Geral', '6.0', 'RASPAGEM PERIODONTAL SIMPLES POR ARCADA', 60, 10, 0, null, 270),
  ('Clínica Geral', '6.1', 'RASPAGEM PERIODONTAL A RETALHO', 90, 60, 0, null, 280),
  ('Implante', '7.0', 'IMPLANTE UNITÁRIO', 0, 0, 0, null, 290),
  ('Implante', '7.1', 'IMPLANTE UNITÁRIO COM ENXERTO ÓSSEO', 0, 0, 0, null, 300),
  ('Ortodontia', '8.0', 'MANUTENÇÃO ORTODONTICA CONVENCIONAL NAC', 30, 7, 0, 120, 310),
  ('Ortodontia', '8.1', 'MANUTENÇÃO ORTODONTICA CONVENCIONAL IMP', 30, 7.5, 0, 120, 320),
  ('Ortodontia', '8.2', 'MANUTENÇÃO ORTODONTICA AUTOLIGADO METÁLICO', 30, 20, 0, 220, 330),
  ('Ortodontia', '8.3', 'MANUTENÇÃO ORTODONTICA SAFIRA', 30, 60, 0, 260, 340),
  ('Ortodontia', '9.0', 'INSTALAÇÃO APARELHO METÁLICO CONV NACIONAL', 90, 36.78, 0, 450, 350),
  ('Ortodontia', '9.1', 'INSTALAÇÃO APARELHO METÁLICO CONV IMPORTADO', 90, 39.78, 0, 700, 360),
  ('Ortodontia', '9.2', 'INSTALAÇÃO APARELHO AUTOLIGADO METÁLICO', 90, 297.48, 0, 1200, 370),
  ('Ortodontia', '9.3', 'INSTALAÇÃO APARELHO SAFIRA', 90, 808.78, 0, 2600, 380),
  ('Ortodontia', '10.0', 'INVISALIGN LIGHT', 180, 5607, 0, 7000, 390),
  ('Ortodontia', '10.1', 'INVISALIGN MODERATE', 420, 7639, 0, 10000, 400),
  ('Ortodontia', '10.2', 'INVISALIGN COMPREHENSIVE', 900, 8480, 0, 14000, 410),
  ('Ortodontia', '10.3', 'CONTENÇÃO INVISALIGN', 60, 555, 0, 1000, 420),
  ('Ortodontia', '11.0', 'CONTENÇÃO HAWLEY', 0, 120, 0, 300, 430),
  ('Ortodontia', '11.1', 'CONTENÇÃO 3X3', 60, 100, 0, 300, 440),
  ('Ortodontia', '11.2', 'CONTENÇÃO HAWLEY E 3X3', 60, 150, 0, 500, 450),
  ('Ortodontia', '11.3', 'CONTENÇÃO MOLDEIRA TIPO INVISALIGN', 90, 120, 0, 600, 460),
  ('Ortodontia', '11.4', 'CONTENÇÃO TIPO INVISALIGN E 3X3', 60, 220, 0, 800, 470),
  ('Ortodontia', '12.0', 'APARELHO HAAS', 120, 250, 0, 700, 480),
  ('Ortodontia', '12.1', 'APARELHO HAAS COM TRAÇÃO REVERSA', 120, 250, 0, 700, 490),
  ('Ortodontia', '12.2', 'APARELHO MÁSCARA FACIAL', 30, 49.8, 0, 350, 500),
  ('Ortodontia', '12.3', 'APARELHO BIONATOR', 60, 280, 0, 700, 510),
  ('HOF', '100.0', 'PREENCHIMENTO LABIAL 1 SERINGA RENNOVA FILL', 90, 450, 0, 880, 520),
  ('HOF', '100.1', 'PREENCHIMENTO LABIAL 1 SERINGA KISSYE RESTYLANE', 90, 550, 0, 1200, 530),
  ('HOF', '100.2', 'SERINGA PREENCHEDOR RENNOVA LIFT', 90, 450, 0, 880, 540),
  ('HOF', '100.3', 'SERINGA PREENCHEDOR RESTYLANE', 90, 450, 0, 1200, 550),
  ('HOF', null, 'SERINGA PREENCHEDOR DEEP PERFETHA', 90, 450, 0, 1200, 560),
  ('HOF', null, 'SERINGA ELLANSE', 0, 0, 0, 1200, 570),
  ('HOF', null, 'BIOESTIMULADOR HIDROXIAPATITA DE CÁLCIO NEXT (SESSÃO)', 0, 0, 0, null, 580),
  ('HOF', null, 'BIOESTIMULADOR HIDROXIAPATITA DE CÁLCIO +AC POLLATICO NEXT', 0, 0, 0, 800, 590),
  ('HOF', null, 'MICROAGULHAMENTO COM MESCLA PARA MELASMA', 0, 0, 0, 150, 600),
  ('HOF', null, 'HIDRALIPS', 0, 0, 0, 150, 610),
  ('HOF', null, 'PEELING ÁCIDO RETINOICO', 0, 0, 0, null, 620),
  ('HOF', null, 'LIPO DE PAPADA CIRÚRGICA', 0, 0, 0, 5500, 630),
  ('HOF', null, 'BOTOX TESTA', 0, 0, 0, 110, 640),
  ('HOF', null, 'BOTOX OLHOS', 0, 0, 0, 420, 650),
  ('HOF', null, 'BOTOX GLABELA', 0, 0, 0, 770, 660),
  ('HOF', null, 'BOTOX TERÇO SUPERIOR', 0, 0, 0, 2000, 670);
