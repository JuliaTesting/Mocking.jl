
@test_logs (:warn, r"no longer required") (@mock identity(1))

@test_logs (:warn, r"no longer required") (Mocking.enable())
@test_logs (:warn, r"no longer required") (Mocking.enable(; force=true))

