import app/api/web
import app/types/app_error
import app/types/page.{Page}
import gleam/json
import wisp

fn body(response: wisp.Response) -> String {
  let assert wisp.Text(text) = response.body
  text
}

pub fn success_is_wrapped_in_the_envelope_test() {
  let response = web.json_ok(json.object([#("id", json.string("usr_1"))]))
  assert response.status == 200
  assert body(response)
    == "{\"status\":true,\"code\":200,\"message\":\"Success\",\"data\":{\"id\":\"usr_1\"},\"errors\":null}"
}

pub fn an_error_carries_its_message_code_and_kind_test() {
  let response = web.error_response(app_error.Conflict("Email taken"))
  assert response.status == 409
  assert body(response)
    == "{\"status\":false,\"code\":409,\"message\":\"Email taken\",\"data\":null,\"errors\":[{\"message\":\"Email taken\",\"statusCode\":409,\"exception\":\"Conflict\"}]}"
}

pub fn a_server_failure_hides_its_cause_test() {
  let response = web.error_response(app_error.Unexpected("disk on fire"))
  assert response.status == 500
  assert body(response)
    == "{\"status\":false,\"code\":500,\"message\":\"Something went wrong\",\"data\":null,\"errors\":[{\"message\":\"Something went wrong\",\"statusCode\":500,\"exception\":\"ServerError\"}]}"
}

pub fn a_page_reports_where_it_is_test() {
  let response =
    web.respond_page(
      Ok(Page(items: [1, 2], number: 2, size: 2, total: 5)),
      json.int,
    )
  assert response.status == 200
  assert body(response)
    == "{\"status\":true,\"code\":200,\"message\":\"Success\",\"data\":[1,2],\"metadata\":{\"pageNumber\":2,\"pageSize\":2,\"totalCount\":5},\"errors\":null}"
}
