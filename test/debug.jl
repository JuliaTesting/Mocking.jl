@testset "_print_module_path_file" begin
    using Mocking: _print_module_path_file

    @testset "no module" begin
        call_site = sprint(_print_module_path_file, nothing, "no-module.jl", 1)
        if VERSION >= v"1.9"
            @test call_site == "@ no-module.jl:1"
        else
            @test call_site == "in no-module.jl:1"
        end
    end

    @testset "no file" begin
        @test_throws MethodError sprint(_print_module_path_file, Main, nothing, 1)
    end

    @testset "no line" begin
        @test_throws MethodError sprint(_print_module_path_file, Main, "file.jl", nothing)
    end

    @testset "contractuser" begin
        call_site = sprint(_print_module_path_file, Main, joinpath(homedir(), "user.jl"), 2)
        if VERSION >= v"1.9"
            @test call_site == "@ Main $(joinpath("~", "user.jl")):2"
        else
            @test call_site == "in Main at $(joinpath(homedir(), "user.jl")):2"
        end
    end

    @testset "source" begin
        call_site = sprint(_print_module_path_file, Main, LineNumberNode(3, "source.jl"))
        if VERSION >= v"1.9"
            @test call_site == "@ Main source.jl:3"
        else
            @test call_site == "in Main at source.jl:3"
        end
    end
end
