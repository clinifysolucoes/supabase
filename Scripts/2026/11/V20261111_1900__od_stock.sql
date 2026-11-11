-- ============================================================================
-- Estoque de materiais (sobre o catalogo da precificacao, od.material).
-- O saldo fica em unidades de uso do material (a mesma unidade da ficha
-- tecnica do procedimento, od.procedure_material.qt_used); a compra pode ser
-- informada em embalagens (x rendimento).
--
--   od.stock_item      materiais com controle de estoque: saldo e minimo
--   od.stock_movement  entradas, saidas, ajustes de inventario e a baixa
--                      automatica pela evolucao clinica (e o estorno quando
--                      a evolucao e excluida)
--
-- Tela nova STOCK (Gestao).
-- ============================================================================

create table od.stock_item (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_material      bigint         not null,
  qt_stock         numeric(14,3)  not null default 0,
  qt_min           numeric(14,3),
  it_status        smallint       not null default 1,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint stock_item_pk primary key (nr_company, nr_branch, nr_material),
  constraint stock_item_material_fk foreign key (nr_company, nr_branch, nr_material)
    references od.material (nr_company, nr_branch, nr_material),
  constraint stock_item_min_check check (qt_min is null or qt_min >= 0),
  constraint stock_item_status_check check (it_status in (1, 90))
);
alter table od.stock_item enable row level security;

create table od.stock_movement (
  nr_company       bigint         not null,
  nr_branch        bigint         not null,
  nr_movement      bigint         not null,
  nr_material      bigint         not null,
  it_type          smallint       not null,
  dt_movement      date           not null,
  qt_quantity      numeric(14,3)  not null,
  qt_balance       numeric(14,3)  not null,
  vl_unit_cost     numeric(14,4),
  vl_total         numeric(14,2),
  nr_supplier      bigint,
  vc_document      varchar(60),
  nr_entry         bigint,
  nr_patient       bigint,
  nr_evolution     bigint,
  nr_movement_ref  bigint,
  vc_notes         varchar(500),
  nr_user          bigint         not null,
  nr_operator      bigint,
  dh_created       timestamptz    not null default now(),
  dh_updated       timestamptz    not null default now(),
  constraint stock_movement_pk primary key (nr_company, nr_branch, nr_movement),
  constraint stock_movement_item_fk foreign key (nr_company, nr_branch, nr_material)
    references od.stock_item (nr_company, nr_branch, nr_material),
  constraint stock_movement_supplier_fk foreign key (nr_company, nr_branch, nr_supplier)
    references od.fin_supplier (nr_company, nr_branch, nr_supplier),
  constraint stock_movement_entry_fk foreign key (nr_company, nr_branch, nr_entry)
    references od.fin_entry (nr_company, nr_branch, nr_entry),
  constraint stock_movement_patient_fk foreign key (nr_company, nr_branch, nr_patient)
    references od.patient (nr_company, nr_branch, nr_patient),
  constraint stock_movement_evolution_fk foreign key (nr_company, nr_branch, nr_patient, nr_evolution)
    references od.clinical_evolution (nr_company, nr_branch, nr_patient, nr_evolution),
  constraint stock_movement_user_fk foreign key (nr_user) references ad.app_user (nr_user),
  constraint stock_movement_type_check check (it_type in (1, 2, 3, 4, 5)),
  constraint stock_movement_quantity_check check (qt_quantity <> 0),
  constraint stock_movement_sign_check check ((it_type in (1, 5) and qt_quantity > 0)
                                           or (it_type in (2, 4) and qt_quantity < 0)
                                           or it_type = 3)
);
create index stock_movement_material_idx on od.stock_movement (nr_company, nr_branch, nr_material, dt_movement);
create index stock_movement_date_idx on od.stock_movement (nr_company, nr_branch, dt_movement);
create index stock_movement_evolution_idx on od.stock_movement (nr_company, nr_branch, nr_patient, nr_evolution)
  where nr_evolution is not null;
alter table od.stock_movement enable row level security;

insert into ad.screen (uu_screen, vc_code, vc_name, vc_group, nr_order) values
  ('0d6a1f3e-1b2c-4d5e-8f90-000000000013', 'STOCK', 'Estoque', 'Gestão', 18);
