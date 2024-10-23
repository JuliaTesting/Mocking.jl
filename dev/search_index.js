var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"CurrentModule = Mocking","category":"page"},{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"","category":"page"},{"location":"api/","page":"API","title":"API","text":"Mocking.activate\nMocking.activated\nMocking.nullify\nMocking.@mock\nMocking.@patch\nMocking.apply","category":"page"},{"location":"api/#Mocking.activate","page":"API","title":"Mocking.activate","text":"Mocking.activate() -> Nothing\n\nActivates @mock call sites to allow for calling patches instead of the original function. Intended to be called within a packages test/runtests.jl file.\n\nnote: Note\nCalling this causes functions which use @mock to become invalidated and re-compiled the next time they are called.\n\n\n\n\n\n","category":"function"},{"location":"api/#Mocking.activated","page":"API","title":"Mocking.activated","text":"Mocking.activated() -> Bool\n\nIndicates if Mocking has been activated or not via Mocking.activate.\n\n\n\n\n\n","category":"function"},{"location":"api/#Mocking.nullify","page":"API","title":"Mocking.nullify","text":"Mocking.nullify() -> Nothing\n\nForce any packages loaded after this point to treat the @mock macro as a no-op. Doing so will maximize performance by eliminating any runtime checks taking place at the @mock call sites but will break any tests that require patches to be applied.\n\nNote to ensure that all @mock macros are inoperative be sure to call this function before loading any packages which depend on Mocking.jl.\n\n\n\n\n\n","category":"function"},{"location":"api/#Mocking.@mock","page":"API","title":"Mocking.@mock","text":"@mock expr\n\nAllows the call site function to be temporarily overloaded via an applied patch.\n\nThe @mock macro works as no-op until Mocking.activate has been called. Once Mocking has been activated then alternative methods defined via @patch can be used with apply to call the patched methods from within the apply context.\n\nSee also: @patch, apply.\n\nExamples\n\njulia> f() = @mock time();\n\njulia> p = @patch time() = 0.0;  # UNIX epoch\n\njulia> apply(p) do\n           Dates.unix2datetime(f())\n       end\n1970-01-01T00:00:00\n\n\n\n\n\n","category":"macro"},{"location":"api/#Mocking.@patch","page":"API","title":"Mocking.@patch","text":"@patch expr\n\nCreates a patch from a function definition. A patch can be used with apply to temporarily include the patch when performing multiple dispatch on @mocked call sites.\n\nSee also: @mock, apply.\n\n\n\n\n\n","category":"macro"},{"location":"api/#Mocking.apply","page":"API","title":"Mocking.apply","text":"apply(body::Function, patches) -> Any\n\nApplies one or more patches during execution of body. Specifically ,any @mock call sites encountered while running body will include the provided patches when performing dispatch.\n\nMultiple-dispatch is used to determine which method to call when utilizing multiple patches. However, patch defined methods always take precedence over the original function methods.\n\nnote: Note\nEnsure you have called activate prior to calling apply as otherwise the provided patches will be ignored.\n\nSee also: @mock, @patch.\n\nExamples\n\nApplying a patch allows the alternative patch function to be called:\n\njulia> f() = \"original\";\n\njulia> p = @patch f() = \"patched\";\n\njulia> apply(p) do\n            @mock f()\n       end\n\"patched\"\n\nPatches take precedence over the original function even when the original method is more specific:\n\njulia> f(::Int) = \"original\";\n\njulia> p = @patch f(::Any) = \"patched\";\n\njulia> apply(p) do\n            @mock f(1)\n       end\n\"patched\"\n\nHowever, when the patches do not provide a valid method to call then the original function will be used as a fallback:\n\njulia> f(::Int) = \"original\";\n\njulia> p = @patch f(::Char) = \"patched\";\n\njulia> apply(p) do\n           @mock f(1)\n       end\n\"original\"\n\nNesting\n\nNesting multiple apply calls is allowed. When multiple patches are provided for the same method then the innermost patch takes precedence:\n\njulia> f() = \"original\";\n\njulia> p1 = @patch f() = \"p1\";\n\njulia> p2 = @patch f() = \"p2\";\n\njulia> apply(p1) do\n           apply(p2) do\n               @mock f()\n           end\n       end\n\"p2\"\n\nWhen multiple patches are provided for different methods then multiple-dispatch is used to select the most specific patch:\n\njulia> f(::Int) = \"original\";\n\njulia> p1 = @patch f(::Integer) = \"p1\";\n\njulia> p2 = @patch f(::Number) = \"p2\";\n\njulia> apply(p1) do\n           apply(p2) do\n               @mock f(1)\n           end\n       end\n\"p1\"\n\n\n\n\n\n","category":"function"},{"location":"#Mocking","page":"Home","title":"Mocking","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Allows Julia function calls to be temporarily overloaded for the purpose of testing.","category":"page"},{"location":"#randdev-Example","page":"Home","title":"randdev Example","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Suppose you wrote the function randdev (UNIX only). How would you go about writing tests for it?","category":"page"},{"location":"","page":"Home","title":"Home","text":"function randdev(n::Integer)\n    open(\"/dev/urandom\") do fp\n        reverse(read(fp, n))\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"The non-deterministic behaviour of this function makes it hard to test but we can write some tests dealing with the deterministic properties of the function such as:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Test\n# using ...: randdev\n\nn = 10\nresult = randdev(n)\n@test eltype(result) == UInt8\n@test length(result) == n","category":"page"},{"location":"","page":"Home","title":"Home","text":"How could we create a test that shows the output of the function is reversed? Mocking.jl provides the @mock macro which allows package developers to temporarily overload a specific calls in their package. In this example we will apply @mock to the open call in randdev:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Mocking: @mock\n\nfunction randdev(n::Integer)\n    @mock open(\"/dev/urandom\") do fp\n        reverse(read(fp, n))\n    end\nend","category":"page"},{"location":"","page":"Home","title":"Home","text":"With the call site being marked as \"mockable\" we can now write a testcase which allows us to demonstrate the reversing behaviour within the randdev function:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using Mocking\nusing Test\n# using ...: randdev\n\nMocking.activate()  # Need to call `activate` before executing `apply`\n\nn = 10\nresult = randdev(n)\n@test eltype(result) == UInt8\n@test length(result) == n\n\n# Produces a string with sequential UInt8 values from 1:n\ndata = unsafe_string(pointer(convert(Array{UInt8}, 1:n)))\n\n# Generate an alternative method of `open` which call we wish to mock\npatch = @patch open(fn::Function, f::AbstractString) = fn(IOBuffer(data))\n\n# Apply the patch which will modify the behaviour for our test\napply(patch) do\n    @test randdev(n) == convert(Array{UInt8}, n:-1:1)\nend\n\n# Outside of the scope of the patched environment `@mock` is essentially a no-op\n@test randdev(n) != convert(Array{UInt8}, n:-1:1)","category":"page"},{"location":"faq/#FAQ","page":"FAQ","title":"FAQ","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"CurrentModule = Mocking","category":"page"},{"location":"faq/#What-kind-of-overhead-does-@mock-add?","page":"FAQ","title":"What kind of overhead does @mock add?","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"The @mock macro is a no-op and has zero overhead when mocking has not been activated via Mocking.activate(). Users can use @code_llvm on their code with and without @mock to confirm the macro has no effect.","category":"page"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"When Mocking.activate is called Mocking.jl will re-define a function utilized by @mock which results in invalidating any functions using the macro. The result of this is that when running your tests will cause those functions to be recompiled the next time they are called such that the alternative code path provided by patches can be executed.","category":"page"},{"location":"faq/#Why-isn't-my-patch-being-called?","page":"FAQ","title":"Why isn't my patch being called?","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"When your patch isn't being applied you should remember to check for the following:","category":"page"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"Mocking.activate is called before the apply call.\nCall sites you want to patch are using @mock.\nThe patch's argument types are supertypes the values passed in at the call site.","category":"page"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"You can also start Julia with JULIA_DEBUG=Mocking to show details about what methods are being dispatched to from @mocked call sites. These interception messages are only displayed if Mocking.activate has been called.","category":"page"},{"location":"faq/#Where-should-I-add-Mocking.activate()?","page":"FAQ","title":"Where should I add Mocking.activate()?","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"We recommend putting the call to Mocking.activate in your package's test/runtests.jl file after all of your import statements. The only true requirement is that you call  Mocking.activate() before the first apply call.","category":"page"},{"location":"faq/#What-if-I-want-to-call-the-un-patched-function-inside-a-patch?","page":"FAQ","title":"What if I want to call the un-patched function inside a patch?","text":"","category":"section"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"Simply call the function without using @mock within the patch. For example we can count the number of calls a recursive function does like this:","category":"page"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"function fibonacci(n)\n    if n <= 1\n        return n\n    else\n        return @mock(fibonacci(n - 1)) + @mock(fibonacci(n - 2))\n    end\nend\n\ncalls = Ref(0)\np = @patch function fibonacci(n)\n    calls[] += 1\n    return fibonacci(n)  # Calls original function\nend\n\napply(p) do\n    @test @mock(fibonacci(1)) == 1\n    @test calls[] == 1\n\n    calls[] = 0\n    @test @mock(fibonacci(4)) == 3\n    @test calls[] == 9\nend","category":"page"},{"location":"faq/","page":"FAQ","title":"FAQ","text":"Note that you can also use @mock inside a patch, which can be useful when using multiple dispatch with patches.","category":"page"}]
}