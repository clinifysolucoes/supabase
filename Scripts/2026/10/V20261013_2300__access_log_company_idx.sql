-- ============================================================================
-- Indice para a tela de logs (ad.access_log_list): o administrador consulta o
-- log por empresa, do mais recente para o mais antigo. O indice existente
-- (nr_user, dh_access desc) atende apenas a consulta "meus acessos".
-- ============================================================================

create index access_log_nr_company_idx on ad.access_log (nr_company, dh_access desc);
