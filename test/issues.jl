# https://github.com/JuliaTesting/Mocking.jl/issues/92
@testset "ContextVariableX logging incompatibility" begin
    generate_report() = "original"
    report_patch = @patch generate_report() = "mocked"

    apply(report_patch) do
        @test (@test_logs @mock generate_report()) == "mocked"
    end
end
