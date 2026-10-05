import app/db/sql_script

pub fn splits_on_top_level_semicolons_test() {
  assert sql_script.split_statements(
      "create table a (id int);\ncreate table b (id int);",
    )
    == ["create table a (id int)", "create table b (id int)"]
}

pub fn ignores_semicolons_inside_strings_and_identifiers_test() {
  assert sql_script.split_statements(
      "insert into notes (body) values ('a;b''c'); select \"odd;name\" from t;",
    )
    == [
      "insert into notes (body) values ('a;b''c')",
      "select \"odd;name\" from t",
    ]
}

pub fn drops_comments_and_empty_statements_test() {
  assert sql_script.split_statements(
      "-- leading; comment\ncreate table a (id int); /* block; /* nested; */ */ ;\n-- trailing",
    )
    == ["create table a (id int)"]
}

pub fn keeps_dollar_quoted_bodies_intact_test() {
  let function =
    "create function touch() returns trigger language plpgsql as $body$ begin new.updated_at = now(); return new; end; $body$"
  assert sql_script.split_statements(function <> "; select 1;")
    == [function, "select 1"]
  assert sql_script.split_statements("do $$ begin perform 1; end $$;")
    == ["do $$ begin perform 1; end $$"]
}

pub fn positional_parameters_are_not_dollar_quotes_test() {
  assert sql_script.split_statements("prepare q as select $1; select 2;")
    == ["prepare q as select $1", "select 2"]
}
