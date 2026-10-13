/* GERADO por tools/gen-dictionary.mjs a partir de schema.json - nao editar */
window.DICTIONARY = {
  "project": "Supabase multi-company login",
  "subtitle": "Base multi-empresa / multi-filial do futuro sistema de odontologia",
  "schema": "ad",
  "schema_title": "AD - Administrative",
  "updated": "2026-10-13",
  "prefixes": {
    "nr_": "Numérico / identificador (bigint, smallint)",
    "vc_": "Texto (varchar, text)",
    "it_": "Indicador / tipo codificado (smallint com lista de valores)",
    "id_": "Booleano (true/false)",
    "dt_": "Data (date)",
    "dh_": "Data e hora com fuso (timestamptz)",
    "qt_": "Quantidade",
    "vl_": "Valor monetário (numeric)",
    "pc_": "Percentual",
    "uu_": "UUID"
  },
  "audit_columns": [
    {
      "name": "nr_operator",
      "type": "bigint",
      "nullable": true,
      "default": null,
      "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
    },
    {
      "name": "dh_created",
      "type": "timestamptz",
      "nullable": false,
      "default": "now()",
      "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
    },
    {
      "name": "dh_updated",
      "type": "timestamptz",
      "nullable": false,
      "default": "now()",
      "description": "Data/hora da última atualização (trigger ad.trg_audit)."
    }
  ],
  "tables": [
    {
      "name": "company",
      "title": "Empresa",
      "description": "Empresa (tenant principal). Toda informação de negócio pertence a uma empresa e, dentro dela, a uma filial.",
      "rls": "SELECT: empresas em que o usuário tem pelo menos uma filial acessível (private.fn_my_companies). Escrita só via company_create / company_update.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Número da empresa."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome da empresa."
        },
        {
          "name": "vc_cnpj",
          "type": "varchar(14)",
          "uk": "company_vc_cnpj_uk",
          "nullable": true,
          "description": "CNPJ sem pontuação, 14 posições. Aceita o CNPJ alfanumérico (12 posições [A-Z0-9] + 2 dígitos). Único quando informado."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "nullable": true,
          "description": "E-mail de contato da empresa (minúsculo)."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone principal (DDD + número, livre)."
        },
        {
          "name": "it_size",
          "type": "smallint",
          "nullable": true,
          "description": "Porte da empresa.",
          "values": {
            "10": "MEI",
            "20": "Micro empresa (ME)",
            "30": "Pequeno porte (EPP)",
            "40": "Médio porte",
            "50": "Grande porte"
          }
        },
        {
          "name": "vc_address",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Logradouro."
        },
        {
          "name": "vc_address_number",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Número do endereço."
        },
        {
          "name": "vc_address_extra",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Complemento do endereço."
        },
        {
          "name": "vc_district",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Bairro."
        },
        {
          "name": "vc_city",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Cidade."
        },
        {
          "name": "vc_state",
          "type": "char(2)",
          "nullable": true,
          "description": "UF (2 letras maiúsculas)."
        },
        {
          "name": "vc_zip_code",
          "type": "varchar(8)",
          "nullable": true,
          "description": "CEP, 8 dígitos sem pontuação."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da empresa.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "dh_status",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última mudança de situação."
        },
        {
          "name": "id_blocked",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Empresa bloqueada pela plataforma (inadimplência, abuso). Bloqueada = ninguém entra; o motivo aparece em session_context.blocked."
        },
        {
          "name": "dh_blocked",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do bloqueio."
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio, exibido ao usuário."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "branch",
      "title": "Filial",
      "description": "Filial (unidade/clínica) da empresa. PK composta (nr_company, nr_branch) com numeração sequencial por empresa. Toda tabela de negócio futura referencia (nr_company, nr_branch).",
      "rls": "SELECT: filiais acessíveis ao usuário (private.fn_my_branches). Escrita só via company_create (matriz), branch_create e branch_update.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "nullable": false,
          "description": "Número da filial, sequencial dentro da empresa (1 = matriz criada com a empresa)."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome fantasia da filial."
        },
        {
          "name": "vc_legal_name",
          "type": "varchar(80)",
          "nullable": true,
          "description": "Razão social."
        },
        {
          "name": "vc_cnpj",
          "type": "varchar(14)",
          "uk": "branch_vc_cnpj_uk",
          "nullable": true,
          "description": "CNPJ da filial, sem pontuação (alfanumérico aceito). Único quando informado."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "nullable": true,
          "description": "E-mail de contato da filial."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone principal."
        },
        {
          "name": "it_size",
          "type": "smallint",
          "nullable": true,
          "description": "Porte da filial.",
          "values": {
            "10": "MEI",
            "20": "Micro empresa (ME)",
            "30": "Pequeno porte (EPP)",
            "40": "Médio porte",
            "50": "Grande porte"
          }
        },
        {
          "name": "it_tax_regime",
          "type": "smallint",
          "nullable": true,
          "description": "Regime tributário.",
          "values": {
            "10": "Simples Nacional MEI (SIMEI)",
            "20": "Simples Nacional",
            "30": "Lucro Real",
            "40": "Lucro Presumido",
            "50": "Lucro Arbitrado"
          }
        },
        {
          "name": "vc_state_registration",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Inscrição estadual."
        },
        {
          "name": "vc_city_registration",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Inscrição municipal."
        },
        {
          "name": "vc_address",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Logradouro."
        },
        {
          "name": "vc_address_number",
          "type": "varchar(10)",
          "nullable": true,
          "description": "Número do endereço."
        },
        {
          "name": "vc_address_extra",
          "type": "varchar(60)",
          "nullable": true,
          "description": "Complemento do endereço."
        },
        {
          "name": "vc_district",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Bairro."
        },
        {
          "name": "vc_city",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Cidade."
        },
        {
          "name": "vc_state",
          "type": "char(2)",
          "nullable": true,
          "description": "UF."
        },
        {
          "name": "vc_zip_code",
          "type": "varchar(8)",
          "nullable": true,
          "description": "CEP, 8 dígitos."
        },
        {
          "name": "vc_timezone",
          "type": "varchar(60)",
          "nullable": false,
          "default": "'America/Sao_Paulo'",
          "description": "Fuso horário IANA da filial (validado em pg_timezone_names). Base da agenda da clínica."
        },
        {
          "name": "id_main",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Matriz. Única por empresa (índice branch_id_main_uk)."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação da filial.",
          "values": {
            "1": "Ativa",
            "90": "Inativa"
          }
        },
        {
          "name": "dh_status",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última mudança de situação."
        },
        {
          "name": "id_blocked",
          "type": "boolean",
          "nullable": false,
          "default": "false",
          "description": "Filial bloqueada pela plataforma."
        },
        {
          "name": "dh_blocked",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do bloqueio."
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "app_user",
      "title": "Usuário",
      "description": "Usuário do sistema. A autenticação (e-mail, senha, OTP, social, 2FA, tentativas) é do Supabase Auth (auth.users); aqui ficam o id numérico, nome e dados do app. Criado automaticamente pelo trigger ad.trg_auth_user_sync no signup.",
      "rls": "SELECT: o próprio cadastro, ou cadastros de usuários vinculados a uma empresa que o usuário administra (private.fn_is_admin_of_user). Escrita só via user_update (próprio) e triggers.",
      "columns": [
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Código do usuário."
        },
        {
          "name": "uu_auth",
          "type": "uuid",
          "uk": "app_user_uu_auth_uk",
          "fk": "auth.users.id",
          "nullable": false,
          "description": "Id do usuário no Supabase Auth (claim sub do JWT = auth.uid()). ON DELETE CASCADE."
        },
        {
          "name": "vc_name",
          "type": "varchar(60)",
          "nullable": false,
          "description": "Nome do usuário (vem de raw_user_meta_data.name no signup)."
        },
        {
          "name": "vc_email",
          "type": "varchar(200)",
          "uk": "app_user_vc_email_uk",
          "nullable": true,
          "description": "E-mail em minúsculo, espelho de auth.users.email (trigger). Nulo em login só por telefone. Usado por company_user_save para localizar quem vincular."
        },
        {
          "name": "vc_cpf",
          "type": "varchar(11)",
          "uk": "app_user_vc_cpf_uk",
          "nullable": true,
          "description": "CPF, 11 dígitos, validado (ad.fn_cpf_is_valid). Único quando informado."
        },
        {
          "name": "vc_phone",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Telefone fixo."
        },
        {
          "name": "vc_mobile",
          "type": "varchar(20)",
          "nullable": true,
          "description": "Celular."
        },
        {
          "name": "vc_avatar_url",
          "type": "text",
          "nullable": true,
          "description": "URL da foto no Supabase Storage."
        },
        {
          "name": "it_level",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Nível do usuário na plataforma. Alterável só por service_role.",
          "values": {
            "0": "Normal",
            "100": "Administrador da plataforma (suporte)"
          }
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do usuário na plataforma. Bloqueado/inativo não enxerga nada (private.fn_current_user_nr retorna NULL).",
          "values": {
            "1": "Ativo",
            "80": "Bloqueado",
            "90": "Inativo"
          }
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio (devolvido em SESSION_USER_BLOCKED)."
        },
        {
          "name": "dh_last_login",
          "type": "timestamptz",
          "nullable": true,
          "description": "Data/hora do último session_context (login no app)."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "access_profile",
      "title": "Perfil de acesso",
      "description": "Perfil de acesso da empresa (Administrador, Dentista, Recepção...). Numeração sequencial por empresa. company_create cria 1 = Administrador (nível 100) e 2 = Usuário (nível 0). A ligação perfil x telas ainda não existe neste projeto.",
      "rls": "SELECT: perfis das empresas acessíveis (private.fn_my_companies). Escrita só via access_profile_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_profile",
          "type": "bigint",
          "pk": 2,
          "nullable": false,
          "description": "Código do perfil, sequencial dentro da empresa."
        },
        {
          "name": "vc_name",
          "type": "varchar(30)",
          "uk": "access_profile_vc_name_uk (nr_company, vc_name)",
          "nullable": false,
          "description": "Nome do perfil, único na empresa."
        },
        {
          "name": "it_level",
          "type": "smallint",
          "nullable": false,
          "default": "0",
          "description": "Nível hierárquico 0..100. 100 = administrador da empresa (private.fn_is_company_admin).",
          "values": {
            "0": "Usuário comum",
            "100": "Administrador da empresa"
          }
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do perfil. Inativo não concede acesso.",
          "values": {
            "1": "Ativo",
            "90": "Inativo"
          }
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "company_user",
      "title": "Empresa x Usuário",
      "description": "Vínculo do usuário com a empresa (multi-empresa: um usuário em N empresas). Situação do usuário DENTRO da empresa, independente da situação na plataforma.",
      "rls": "SELECT: os próprios vínculos, ou todos os vínculos das empresas que o usuário administra. Escrita só via company_create (criador) e company_user_save.",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "company.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 2,
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Código do usuário."
        },
        {
          "name": "nr_company_user",
          "type": "bigint",
          "uk": "company_user_nr_company_user_uk (nr_company, nr_company_user)",
          "nullable": false,
          "description": "Código do usuário dentro da empresa, sequencial (1 = criador). Útil como código curto de operador/profissional."
        },
        {
          "name": "it_status",
          "type": "smallint",
          "nullable": false,
          "default": "1",
          "description": "Situação do usuário na empresa.",
          "values": {
            "1": "Ativo",
            "80": "Bloqueado",
            "90": "Inativo"
          }
        },
        {
          "name": "vc_block_reason",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Motivo do bloqueio na empresa (devolvido em session_context.blocked). Limpo ao reativar."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "branch_user_profile",
      "title": "Filial x Usuário x Perfil",
      "description": "Perfis do usuário em cada filial (multi-filial). É esta tabela que dá acesso: sem linha aqui numa filial ativa, o usuário não entra na empresa (SESSION_WITHOUT_PROFILE). ON DELETE CASCADE de branch e company_user.",
      "rls": "SELECT: os próprios vínculos, ou todos das empresas que o usuário administra. Escrita só via company_create, branch_create e company_user_save (ad.fn_set_user_branches).",
      "columns": [
        {
          "name": "nr_company",
          "type": "bigint",
          "pk": 1,
          "fk": "branch.nr_company",
          "nullable": false,
          "description": "Número da empresa."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "pk": 2,
          "fk": "branch.nr_branch",
          "nullable": false,
          "description": "Número da filial."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "pk": 3,
          "fk": "company_user.nr_user",
          "nullable": false,
          "description": "Código do usuário (precisa estar vinculado à empresa em company_user)."
        },
        {
          "name": "nr_profile",
          "type": "bigint",
          "pk": 4,
          "fk": "access_profile.nr_profile",
          "nullable": false,
          "description": "Perfil do usuário nesta filial."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    },
    {
      "name": "access_log",
      "title": "Log de acesso",
      "description": "Uma linha por session_context (login/restauração de sessão no app). IP e user-agent são lidos dos headers HTTP do request pelo PostgREST (request.headers).",
      "rls": "SELECT: os próprios acessos. Escrita só via session_context.",
      "columns": [
        {
          "name": "nr_access",
          "type": "bigint",
          "pk": 1,
          "nullable": false,
          "default": "identity",
          "description": "Número do acesso."
        },
        {
          "name": "nr_user",
          "type": "bigint",
          "fk": "app_user.nr_user",
          "nullable": false,
          "description": "Usuário que acessou."
        },
        {
          "name": "nr_company",
          "type": "bigint",
          "nullable": true,
          "description": "Empresa que o app abriu (quando informada)."
        },
        {
          "name": "nr_branch",
          "type": "bigint",
          "nullable": true,
          "description": "Filial que o app abriu (quando informada)."
        },
        {
          "name": "it_app",
          "type": "smallint",
          "nullable": true,
          "description": "Tipo de aplicativo.",
          "values": {
            "1": "Web",
            "2": "Android",
            "3": "iOS",
            "9": "Outro"
          }
        },
        {
          "name": "vc_ip",
          "type": "varchar(60)",
          "nullable": true,
          "description": "IP de origem (header x-forwarded-for, primeiro valor)."
        },
        {
          "name": "vc_device",
          "type": "varchar(200)",
          "nullable": true,
          "description": "Dispositivo/modelo informado pelo app."
        },
        {
          "name": "vc_user_agent",
          "type": "varchar(800)",
          "nullable": true,
          "description": "Header user-agent do request."
        },
        {
          "name": "vc_app_version",
          "type": "varchar(30)",
          "nullable": true,
          "description": "Versão do app informada em session_context."
        },
        {
          "name": "dh_access",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora do acesso."
        },
        {
          "name": "nr_operator",
          "type": "bigint",
          "nullable": true,
          "default": null,
          "description": "Usuário (ad.app_user.nr_user) da última alteração. Preenchido pelo trigger ad.trg_audit."
        },
        {
          "name": "dh_created",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora de inclusão do registro (trigger ad.trg_audit; nunca muda)."
        },
        {
          "name": "dh_updated",
          "type": "timestamptz",
          "nullable": false,
          "default": "now()",
          "description": "Data/hora da última atualização (trigger ad.trg_audit)."
        }
      ]
    }
  ],
  "external_entities": [
    {
      "name": "auth_users",
      "title": "auth.users (Supabase Auth)",
      "description": "Usuários autenticados pelo Supabase (e-mail, senha, OTP, social, 2FA). Gerenciado pela Supabase; referenciado por ad.app_user.uu_auth."
    }
  ],
  "relations": [
    {
      "from": "company",
      "to": "branch",
      "card": "||--o{",
      "label": "possui filiais"
    },
    {
      "from": "company",
      "to": "access_profile",
      "card": "||--o{",
      "label": "define perfis"
    },
    {
      "from": "company",
      "to": "company_user",
      "card": "||--o{",
      "label": "tem usuários"
    },
    {
      "from": "app_user",
      "to": "company_user",
      "card": "||--o{",
      "label": "participa de empresas"
    },
    {
      "from": "auth_users",
      "to": "app_user",
      "card": "||--||",
      "label": "uu_auth"
    },
    {
      "from": "branch",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "acesso por filial"
    },
    {
      "from": "company_user",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "perfis nas filiais"
    },
    {
      "from": "access_profile",
      "to": "branch_user_profile",
      "card": "||--o{",
      "label": "perfil atribuído"
    },
    {
      "from": "app_user",
      "to": "access_log",
      "card": "||--o{",
      "label": "acessos"
    }
  ],
  "functions": [
    {
      "name": "session_context",
      "signature": "ad.session_context(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Login do app após o Supabase Auth: devolve usuário, empresas → filiais → perfis acessíveis (com it_level e id_admin) e vínculos bloqueados com motivo; grava access_log e dh_last_login.",
      "errors": [
        "VERSION_MISMATCH",
        "SESSION_USER_NOT_FOUND",
        "SESSION_USER_INACTIVE",
        "SESSION_USER_BLOCKED",
        "SESSION_COMPANY_BLOCKED",
        "SESSION_COMPANY_INACTIVE",
        "SESSION_USER_COMPANY_BLOCKED",
        "SESSION_USER_COMPANY_INACTIVE",
        "SESSION_WITHOUT_PROFILE"
      ]
    },
    {
      "name": "company_create",
      "signature": "ad.company_create(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Onboarding: cria empresa, matriz (filial 1), perfis Administrador/Usuário e vincula o criador como administrador. Qualquer usuário ativo pode criar.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_CREATE_USER_NOT_FOUND",
        "COMPANY_CREATE_USER_INACTIVE",
        "COMPANY_CREATE_NAME_REQUIRED",
        "COMPANY_CREATE_CNPJ_INVALID",
        "COMPANY_CREATE_CNPJ_IN_USE",
        "COMPANY_CREATE_EMAIL_INVALID",
        "COMPANY_CREATE_TIMEZONE_INVALID"
      ]
    },
    {
      "name": "company_update",
      "signature": "ad.company_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Atualização parcial dos dados cadastrais da empresa. Somente administrador. Situação/bloqueio só por service_role.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_UPDATE_COMPANY_REQUIRED",
        "COMPANY_UPDATE_FORBIDDEN",
        "COMPANY_UPDATE_NAME_REQUIRED",
        "COMPANY_UPDATE_CNPJ_INVALID",
        "COMPANY_UPDATE_CNPJ_IN_USE",
        "COMPANY_UPDATE_EMAIL_INVALID"
      ]
    },
    {
      "name": "branch_create",
      "signature": "ad.branch_create(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria filial (numeração sequencial por empresa, serializada com FOR UPDATE na empresa) e vincula o criador com o seu perfil de maior nível. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_CREATE_COMPANY_REQUIRED",
        "BRANCH_CREATE_FORBIDDEN",
        "BRANCH_CREATE_NAME_REQUIRED",
        "BRANCH_CREATE_CNPJ_INVALID",
        "BRANCH_CREATE_CNPJ_IN_USE",
        "BRANCH_CREATE_EMAIL_INVALID",
        "BRANCH_CREATE_TIMEZONE_INVALID"
      ]
    },
    {
      "name": "branch_update",
      "signature": "ad.branch_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Atualização parcial da filial, inclusive transferência de matriz (id_main). Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "BRANCH_UPDATE_KEY_REQUIRED",
        "BRANCH_UPDATE_FORBIDDEN",
        "BRANCH_UPDATE_NOT_FOUND",
        "BRANCH_UPDATE_NAME_REQUIRED",
        "BRANCH_UPDATE_CNPJ_INVALID",
        "BRANCH_UPDATE_CNPJ_IN_USE",
        "BRANCH_UPDATE_EMAIL_INVALID",
        "BRANCH_UPDATE_TIMEZONE_INVALID"
      ]
    },
    {
      "name": "access_profile_save",
      "signature": "ad.access_profile_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Cria (I) ou atualiza (U) perfis de acesso da empresa. Guarda contra deixar a empresa sem administrador ativo. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "ACCESS_PROFILE_ACTION_INVALID",
        "ACCESS_PROFILE_COMPANY_REQUIRED",
        "ACCESS_PROFILE_FORBIDDEN",
        "ACCESS_PROFILE_NAME_REQUIRED",
        "ACCESS_PROFILE_NAME_IN_USE",
        "ACCESS_PROFILE_LEVEL_INVALID",
        "ACCESS_PROFILE_REQUIRED",
        "ACCESS_PROFILE_NOT_FOUND",
        "ACCESS_PROFILE_STATUS_INVALID",
        "ACCESS_PROFILE_LAST_ADMIN"
      ]
    },
    {
      "name": "company_user_save",
      "signature": "ad.company_user_save(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Vincula (I, por e-mail de usuário já cadastrado no Auth), altera (U: situação, motivo, filiais/perfis) ou remove (D) um usuário da empresa. Guarda do último administrador. Somente administrador.",
      "errors": [
        "VERSION_MISMATCH",
        "COMPANY_USER_ACTION_INVALID",
        "COMPANY_USER_COMPANY_REQUIRED",
        "COMPANY_USER_FORBIDDEN",
        "COMPANY_USER_EMAIL_REQUIRED",
        "COMPANY_USER_EMAIL_NOT_FOUND",
        "COMPANY_USER_ALREADY_LINKED",
        "COMPANY_USER_USER_REQUIRED",
        "COMPANY_USER_NOT_FOUND",
        "COMPANY_USER_STATUS_INVALID",
        "COMPANY_USER_BRANCHES_REQUIRED",
        "COMPANY_USER_BRANCH_INVALID",
        "COMPANY_USER_PROFILE_INVALID",
        "COMPANY_USER_LAST_ADMIN"
      ]
    },
    {
      "name": "user_update",
      "signature": "ad.user_update(p_json jsonb)",
      "kind": "rpc",
      "grant": "authenticated",
      "description": "Autoatendimento: nome, CPF (validado), telefones e avatar do próprio usuário. E-mail/senha mudam pelo Supabase Auth.",
      "errors": [
        "VERSION_MISMATCH",
        "USER_UPDATE_USER_NOT_FOUND",
        "USER_UPDATE_NAME_REQUIRED",
        "USER_UPDATE_CPF_INVALID",
        "USER_UPDATE_CPF_IN_USE"
      ]
    },
    {
      "name": "fn_current_user_nr",
      "signature": "private.fn_current_user_nr()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "auth.uid() → ad.app_user.nr_user do usuário logado e ativo; NULL sem sessão ou bloqueado. STABLE, SECURITY DEFINER."
    },
    {
      "name": "fn_my_branches",
      "signature": "private.fn_my_branches()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "Pares (nr_company, nr_branch) acessíveis agora: vínculo com perfil ativo, usuário ativo na empresa, empresa e filial ativas e não bloqueadas."
    },
    {
      "name": "fn_my_companies",
      "signature": "private.fn_my_companies()",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "Empresas com pelo menos uma filial acessível (derivada de fn_my_branches)."
    },
    {
      "name": "fn_is_company_admin",
      "signature": "private.fn_is_company_admin(p_nr_company bigint)",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "TRUE se o usuário logado tem perfil ativo de nível ≥ 100 em alguma filial acessível da empresa."
    },
    {
      "name": "fn_is_admin_of_user",
      "signature": "private.fn_is_admin_of_user(p_nr_user bigint)",
      "kind": "helper",
      "grant": "authenticated (usada nas policies; schema private, fora da API)",
      "description": "TRUE se o usuário logado administra alguma empresa em que p_nr_user está vinculado (policy de app_user)."
    },
    {
      "name": "fn_company_has_admin",
      "signature": "ad.fn_company_has_admin(p_nr_company bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "TRUE se a empresa ainda tem um administrador ativo em filial ativa. Guarda anti-lockout de access_profile_save e company_user_save."
    },
    {
      "name": "fn_set_user_branches",
      "signature": "ad.fn_set_user_branches(p_nr_company bigint, p_nr_user bigint, p_branches jsonb, p_nr_operator bigint)",
      "kind": "helper",
      "grant": "interna",
      "description": "Substitui os vínculos filial x perfil de um usuário na empresa, validando filial e perfil."
    },
    {
      "name": "fn_check_version",
      "signature": "ad.fn_check_version(p_nr_version integer, p_nr_expected integer, p_vc_function text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Compara nr_version do app com a versão do contrato da function; RAISE VERSION_MISMATCH se diferente."
    },
    {
      "name": "fn_message",
      "signature": "ad.fn_message(p_vc_key text, p_jb_params jsonb)",
      "kind": "helper",
      "grant": "interna",
      "description": "Monta a mensagem de erro padrão {\"Message\": chave, \"Parameters\": {...}} para o app traduzir."
    },
    {
      "name": "fn_cnpj_is_valid",
      "signature": "ad.fn_cnpj_is_valid(p_vc_cnpj text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Dígitos verificadores do CNPJ, inclusive alfanumérico (07/2026)."
    },
    {
      "name": "fn_cnpj_normalize",
      "signature": "ad.fn_cnpj_normalize(p_vc_cnpj text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Remove pontuação, maiúsculas, NULL para vazio."
    },
    {
      "name": "fn_cpf_is_valid",
      "signature": "ad.fn_cpf_is_valid(p_vc_cpf text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Dígitos verificadores do CPF."
    },
    {
      "name": "fn_email_is_valid",
      "signature": "ad.fn_email_is_valid(p_vc_email text)",
      "kind": "helper",
      "grant": "interna",
      "description": "Validação sintática mínima de e-mail de contato."
    },
    {
      "name": "trg_audit",
      "signature": "ad.trg_audit()",
      "kind": "trigger",
      "grant": "interna",
      "description": "BEFORE INSERT OR UPDATE em todas as tabelas: preenche nr_operator, dh_created, dh_updated."
    },
    {
      "name": "trg_auth_user_sync",
      "signature": "ad.trg_auth_user_sync()",
      "kind": "trigger",
      "grant": "supabase_auth_admin",
      "description": "AFTER INSERT OR UPDATE OF email em auth.users: cria/sincroniza ad.app_user."
    }
  ],
  "mermaid": "erDiagram\n  company ||--o{ branch : \"possui filiais\"\n  company ||--o{ access_profile : \"define perfis\"\n  company ||--o{ company_user : \"tem usuários\"\n  app_user ||--o{ company_user : \"participa de empresas\"\n  auth_users ||--|| app_user : \"uu_auth\"\n  branch ||--o{ branch_user_profile : \"acesso por filial\"\n  company_user ||--o{ branch_user_profile : \"perfis nas filiais\"\n  access_profile ||--o{ branch_user_profile : \"perfil atribuído\"\n  app_user ||--o{ access_log : \"acessos\"\n  auth_users {\n    uuid id PK\n    text email\n  }\n  company {\n    bigint nr_company PK\n    varchar vc_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n  }\n  branch {\n    bigint nr_company PK, FK\n    bigint nr_branch PK\n    varchar vc_name\n    varchar vc_legal_name\n    varchar vc_cnpj UK\n    varchar vc_email\n    varchar vc_phone\n    smallint it_size\n    smallint it_tax_regime\n    varchar vc_state_registration\n    varchar vc_city_registration\n    varchar vc_address\n    varchar vc_address_number\n    varchar vc_address_extra\n    varchar vc_district\n    varchar vc_city\n    char vc_state\n    varchar vc_zip_code\n    varchar vc_timezone\n    boolean id_main\n    smallint it_status\n    timestamptz dh_status\n    boolean id_blocked\n    timestamptz dh_blocked\n    varchar vc_block_reason\n  }\n  app_user {\n    bigint nr_user PK\n    uuid uu_auth FK, UK\n    varchar vc_name\n    varchar vc_email UK\n    varchar vc_cpf UK\n    varchar vc_phone\n    varchar vc_mobile\n    text vc_avatar_url\n    smallint it_level\n    smallint it_status\n    varchar vc_block_reason\n    timestamptz dh_last_login\n  }\n  access_profile {\n    bigint nr_company PK, FK\n    bigint nr_profile PK\n    varchar vc_name UK\n    smallint it_level\n    smallint it_status\n  }\n  company_user {\n    bigint nr_company PK, FK\n    bigint nr_user PK, FK\n    bigint nr_company_user UK\n    smallint it_status\n    varchar vc_block_reason\n  }\n  branch_user_profile {\n    bigint nr_company PK, FK\n    bigint nr_branch PK, FK\n    bigint nr_user PK, FK\n    bigint nr_profile PK, FK\n  }\n  access_log {\n    bigint nr_access PK\n    bigint nr_user FK\n    bigint nr_company\n    bigint nr_branch\n    smallint it_app\n    varchar vc_ip\n    varchar vc_device\n    varchar vc_user_agent\n    varchar vc_app_version\n    timestamptz dh_access\n  }"
};
