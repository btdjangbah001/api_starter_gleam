import gleam/int
import gleam/list

pub type PageRequest {
  PageRequest(number: Int, size: Int)
}

pub type Page(item) {
  Page(items: List(item), number: Int, size: Int, total: Int)
}

pub fn request(number: Int, size: Int, max_size: Int) -> PageRequest {
  PageRequest(number: int.max(number, 1), size: int.clamp(size, 1, max_size))
}

pub fn offset(request: PageRequest) -> Int {
  { request.number - 1 } * request.size
}

pub fn from_rows(
  request: PageRequest,
  rows: List(row),
  total: fn(row) -> Int,
  items: List(item),
) -> Page(item) {
  Page(
    items:,
    number: request.number,
    size: request.size,
    total: case list.first(rows) {
      Ok(row) -> total(row)
      Error(Nil) -> 0
    },
  )
}

pub fn map(page: Page(a), transform: fn(List(a)) -> List(b)) -> Page(b) {
  Page(
    items: transform(page.items),
    number: page.number,
    size: page.size,
    total: page.total,
  )
}
