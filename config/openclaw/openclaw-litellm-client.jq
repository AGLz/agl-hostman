walk(
  if type == "object" and (.baseUrl? | type == "string") and (.baseUrl | test("localhost:4000|127\\.0\\.0\\.1:4000"))
  then .baseUrl = "http://100.94.221.87:4000"
  else .
  end
)
