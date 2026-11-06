-- ============================================================================
-- DRE (Demonstrativo do Resultado do Exercicio) da filial: aliquotas para a
-- estimativa dos impostos no relatorio ad.fin_dre.
--
--   od.branch_setting  + pc_dre_revenue_tax  impostos sobre a receita bruta
--                                              (Simples, ISS, PIS/COFINS; % 0..50)
--                      + pc_dre_income_tax   IRPJ sobre o resultado antes dos
--                                              impostos (% 0..50)
--                      + pc_dre_csll         CSLL sobre o resultado antes dos
--                                              impostos (% 0..50)
--   Zero = nao estima (use uma categoria de despesa para os impostos pagos).
--
-- Leitura por RLS (ja existente); escrita so por ad.settings_save.
-- ============================================================================

alter table od.branch_setting add column pc_dre_revenue_tax numeric(5,2) not null default 0;
alter table od.branch_setting add column pc_dre_income_tax numeric(5,2) not null default 0;
alter table od.branch_setting add column pc_dre_csll numeric(5,2) not null default 0;

alter table od.branch_setting add constraint branch_setting_dre_tax_check
  check (pc_dre_revenue_tax between 0 and 50 and pc_dre_income_tax between 0 and 50 and pc_dre_csll between 0 and 50);
