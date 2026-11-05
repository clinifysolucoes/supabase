-- ============================================================================
-- Financeiro (schema od), fase 4: o que faltava em relacao a outros sistemas.
--
--   od.fin_recurrence   conta recorrente como REGRA (todo mes no dia X, sem
--                       data final ou ate uma data): os lancamentos sao gerados
--                       a partir dela (fin_entry.nr_recurrence) e a regra pode
--                       ser alterada (muda os futuros em aberto) ou encerrada
--   od.fin_entry        + nr_recurrence (de qual regra veio)
--                       + dh_health_exported (quando o recebimento foi exportado
--                         para a Receita Saude)
--   od.fin_receivable   + dados do cartao (bandeira, 4 ultimos digitos,
--                         autorizacao, titular e CPF) e do cheque (banco, numero)
--   od.fin_account      + banco (codigo e nome), agencia e numero da conta
--   od.fin_attachment   anexos das contas (documento: nota/boleto; comprovante
--                       de pagamento). O arquivo fica no Storage (bucket
--                       privado "finance", caminho company/branch/entry/uuid);
--                       a tabela guarda o registro. Upload e download so por
--                       URL assinada da Edge Function fin-attachment, que valida
--                       a permissao pela RPC antes.
--
-- Leitura por RLS (private.fn_my_branches, em rls_od_policies.pgs); escrita so
-- pelas RPCs da tela FINANCE.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- od.fin_recurrence
-- ---------------------------------------------------------------------------
create table od.fin_recurrence (
  nr_company         bigint         not null,
  nr_branch          bigint         not null,
  nr_recurrence      bigint         not null,
  it_kind            smallint       not null,
  nr_category        bigint         not null,
  nr_account         bigint,
  nr_supplier        bigint,
  nr_patient         bigint,
  vc_description     varchar(140)   not null,
  vl_amount          numeric(14,2)  not null,
  it_day             smallint       not null,
  it_payment_method  smallint,
  dt_start           date           not null,
  dt_end             date,
  dt_generated       date,
  it_status          smallint       not null default 1,
  vc_notes           varchar(500),
  nr_user_created    bigint,
  nr_operator        bigint,
  dh_created         timestamptz    not null default now(),
  dh_updated         timestamptz    not null default now(),
  constraint fin_recurrence_pk primary key (nr_company, nr_branch, nr_recurrence),
  constraint fin_recurrence_branch_fk foreign key (nr_company, nr_branch)
    references ad.branch (nr_company, nr_branch),
  constraint fin_recurrence_category_fk foreign key (nr_company, nr_branch, nr_category)
    references od.fin_category (nr_company, nr_branch, nr_category),
  constraint fin_recurrence_account_fk foreign key (nr_company, nr_branch, nr_account)
    references od.fin_account (nr_company, nr_branch, nr_account),
  constraint fin_recurrence_supplier_fk foreign key (nr_company, nr_branch, nr_supplier)
    references od.fin_supplier (nr_company, nr_branch, nr_supplier),
  constraint fin_recurrence_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint fin_recurrence_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_recurrence_it_kind_check     check (it_kind in (1, 2)),
  constraint fin_recurrence_description_check check (length(trim(vc_description)) > 0),
  constraint fin_recurrence_vl_amount_check   check (vl_amount > 0),
  constraint fin_recurrence_it_day_check      check (it_day between 1 and 31),
  constraint fin_recurrence_method_check      check (it_payment_method is null or it_payment_method in (1, 2, 3, 4, 5, 6, 7, 9)),
  constraint fin_recurrence_period_check      check (dt_end is null or dt_end >= dt_start),
  constraint fin_recurrence_it_status_check   check (it_status in (1, 90))
);

alter table od.fin_recurrence enable row level security;

-- ---------------------------------------------------------------------------
-- od.fin_entry: regra de origem e exportacao Receita Saude
-- ---------------------------------------------------------------------------
alter table od.fin_entry add column nr_recurrence bigint;
alter table od.fin_entry add column dh_health_exported timestamptz;
alter table od.fin_entry add constraint fin_entry_recurrence_fk foreign key (nr_company, nr_branch, nr_recurrence)
  references od.fin_recurrence (nr_company, nr_branch, nr_recurrence);
create index fin_entry_recurrence_idx on od.fin_entry (nr_company, nr_branch, nr_recurrence, dt_due)
  where nr_recurrence is not null;

-- ---------------------------------------------------------------------------
-- od.fin_receivable: dados do cartao e do cheque
-- ---------------------------------------------------------------------------
alter table od.fin_receivable add column vc_card_brand varchar(20);
alter table od.fin_receivable add column vc_card_last4 varchar(4);
alter table od.fin_receivable add column vc_authorization varchar(30);
alter table od.fin_receivable add column vc_holder_name varchar(120);
alter table od.fin_receivable add column vc_holder_document varchar(14);
alter table od.fin_receivable add column vc_bank_name varchar(60);
alter table od.fin_receivable add column vc_check_number varchar(20);
alter table od.fin_receivable add constraint fin_receivable_card_last4_check
  check (vc_card_last4 is null or vc_card_last4 ~ '^[0-9]{4}$');
alter table od.fin_receivable add constraint fin_receivable_holder_document_check
  check (vc_holder_document is null or vc_holder_document ~ '^([0-9]{11}|[0-9A-Z]{14})$');

-- ---------------------------------------------------------------------------
-- od.fin_account: dados bancarios
-- ---------------------------------------------------------------------------
alter table od.fin_account add column vc_bank_code varchar(3);
alter table od.fin_account add column vc_bank_name varchar(60);
alter table od.fin_account add column vc_agency varchar(10);
alter table od.fin_account add column vc_account_number varchar(20);
alter table od.fin_account add constraint fin_account_bank_code_check
  check (vc_bank_code is null or vc_bank_code ~ '^[0-9]{3}$');

-- ---------------------------------------------------------------------------
-- od.fin_attachment
-- ---------------------------------------------------------------------------
create table od.fin_attachment (
  nr_company       bigint        not null,
  nr_branch        bigint        not null,
  nr_attachment    bigint        not null,
  nr_entry         bigint        not null,
  it_type          smallint      not null default 1,
  vc_path          varchar(300)  not null,
  vc_name          varchar(200)  not null,
  vc_mime          varchar(100),
  qt_bytes         bigint,
  it_status        smallint      not null default 1,
  nr_user_created  bigint,
  nr_operator      bigint,
  dh_created       timestamptz   not null default now(),
  dh_updated       timestamptz   not null default now(),
  constraint fin_attachment_pk primary key (nr_company, nr_branch, nr_attachment),
  constraint fin_attachment_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint fin_attachment_user_created_fk foreign key (nr_user_created)
    references ad.app_user (nr_user),
  constraint fin_attachment_it_type_check   check (it_type in (1, 2)),
  constraint fin_attachment_name_check      check (length(trim(vc_name)) > 0),
  constraint fin_attachment_bytes_check     check (qt_bytes is null or qt_bytes between 0 and 10485760),
  constraint fin_attachment_it_status_check check (it_status in (1, 90))
);

create unique index fin_attachment_path_uk on od.fin_attachment (vc_path);
create index fin_attachment_entry_idx on od.fin_attachment (nr_company, nr_branch, nr_entry)
  where it_status = 1;

alter table od.fin_attachment enable row level security;
