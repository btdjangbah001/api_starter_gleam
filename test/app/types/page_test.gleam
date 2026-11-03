import app/types/page

pub fn a_page_request_stays_in_bounds_test() {
  assert page.request(0, 500, 200) == page.PageRequest(number: 1, size: 200)
  assert page.request(3, 0, 200) == page.PageRequest(number: 3, size: 1)
}

pub fn the_offset_skips_earlier_pages_test() {
  assert page.offset(page.request(3, 20, 200)) == 40
}
