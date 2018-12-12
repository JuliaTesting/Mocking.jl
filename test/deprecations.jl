
@test_logs (:warn, r"can be removed") (@mock identity(1))

@test_logs (:warn, r"can be removed") (Mocking.enable())
@test_logs (:warn, r"no can be removed") (Mocking.enable(; force=true))
