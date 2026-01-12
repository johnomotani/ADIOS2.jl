@testset "adios_load with steps" begin
    tmp_dir = Base.Filesystem.mktempdir()

    bpName = "$tmp_dir/test.bp"

    # Define test data
    nn = 3
    scalar = rand()
    vector = rand(nn)
    matrix = rand(nn, nn)
    array3D = rand(nn, nn, nn)


    @testset "Write a test.bp file for test" begin

        # write test.bp data
        Nsteps = 10
        file = adios_open_serial(bpName, mode_write)
        for i in 0:(Nsteps - 1)
            begin_step(file.engine)

            adios_put!(file, "step", i)

            # root-level variables
            adios_put!(file, "scalar", scalar)
            adios_put!(file, "vector", vector)
            adios_put!(file, "matrix", matrix)
            adios_put!(file, "array3D", array3D)

            # with complex names
            adios_put!(file, "scalar_A", scalar)
            adios_put!(file, "scalar_B", scalar)
            adios_put!(file, "abc_scalar23", scalar)
            adios_put!(file, "scalar234", scalar)
            adios_put!(file, "deep/in/nested/groups/scalar", scalar)
            adios_put!(file, "another/deep/in/nested/groups/scalar", scalar)

            adios_perform_puts!(file)

            end_step(file.engine)
        end
        close(file)
    end

    @testset "Load all data at once" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        Nsteps = steps(file.engine)

        # read test.bp data using adios_load
        all_data = adios_load(file)

        @test all_data["step"] == 0:(Nsteps - 1)
        @test all_data["scalar"] == fill(scalar, Nsteps)
        @test all_data["vector"] == repeat(vector, 1, Nsteps)
        @test all_data["matrix"] == repeat(matrix, 1, 1, Nsteps)
        @test all_data["array3D"] == repeat(array3D, 1, 1, 1, Nsteps)

        @test all_data["scalar_A"] == fill(scalar, Nsteps)
        @test all_data["scalar_B"] == fill(scalar, Nsteps)
        @test all_data["abc_scalar23"] == fill(scalar, Nsteps)
        @test all_data["scalar234"] == fill(scalar, Nsteps)
        @test all_data["deep/in/nested/groups/scalar"] == fill(scalar, Nsteps)
        @test all_data["another/deep/in/nested/groups/scalar"] ==
              fill(scalar, Nsteps)

        close(file)
    end

    @testset "Load all data at specific steps" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        # single step
        target_step = 2

        all_data = adios_load(file,target_step)
        @test all_data["step"] == target_step
        @test all_data["scalar"] == scalar
        @test all_data["vector"] == vector
        @test all_data["matrix"] == matrix
        @test all_data["array3D"] == array3D

        # Multiple steps: read data from steps 2 to 5
        target_steps = 2:5
        all_data = adios_load(file,target_steps)

        @test all_data["step"] == target_steps
        @test all_data["scalar"] == fill(scalar, length(target_steps))
        @test all_data["vector"] == repeat(vector, 1, length(target_steps))
        @test all_data["matrix"] == repeat(matrix, 1, 1, length(target_steps))
        @test all_data["array3D"] == repeat(array3D, 1, 1, 1, length(target_steps))

        @test all_data["scalar_A"] == fill(scalar, length(target_steps))
        @test all_data["deep/in/nested/groups/scalar"] == fill(scalar, length(target_steps))

        close(file)
    end

    @testset "adios_load basic dispatches" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        Nsteps = steps(file.engine)
        # single variable, all steps
        @test adios_load(file, "step") == 0:(Nsteps - 1)
        @test adios_load(file, "vector") == repeat(vector, 1, Nsteps)
        @test adios_load(file, "vector"; start=(2,)) == repeat(vector[2:end], 1, Nsteps)
        @test adios_load(file, "vector"; count=(2,)) == repeat(vector[1:2], 1, Nsteps)
        @test adios_load(file, "vector"; start=(2,), count=(2,)) == repeat(vector[2:3], 1, Nsteps)

        # single variable, specific step (@ step=3)
        @test adios_load(file, "step", 3) == 3
        @test adios_load(file, "scalar", 3) == scalar
        @test adios_load(file, "array3D", 3) == array3D
        @test adios_load(file, "array3D", 3; start=(1, 2, 3)) == array3D[1:end,2:end,3:end]
        @test adios_load(file, "array3D", 3; count=(2, 2, 1)) == array3D[1:2,1:2,1:1]
        @test adios_load(file, "array3D", 3; start=(1, 2, 3), count=(2, 2, 1)) == array3D[1:2,2:3,3:3]

        # single varialbe, mulitiple steps
        @test adios_load(file, "step", [1, 3, 5]) == [1, 3, 5]
        @test adios_load(file, "step", [5, 3, 1]) == [5, 3, 1]
        @test adios_load(file, "step", 1:3) == 1:3
        @test adios_load(file, "matrix", [1, 3, 5]) == repeat(matrix, 1, 1, 3)
        @test adios_load(file, "matrix", [1, 3, 5]; start=(2, 1)) == repeat(matrix[2:end,1:end], 1, 1, 3)
        @test adios_load(file, "matrix", [1, 3, 5]; count=(2, 1)) == repeat(matrix[1:2,1:1], 1, 1, 3)
        @test adios_load(file, "matrix", [1, 3, 5]; start=(2, 1), count=(2, 1)) == repeat(matrix[2:3,1:1], 1, 1, 3)

        # mulitiple variables, all steps
        @test adios_load(file, ["step", "vector"]) ==
              Dict("step" => 0:(Nsteps - 1),
                   "vector" => repeat(vector, 1, Nsteps))

        # multiple variables, specific step (@ step=3)
        @test adios_load(file, ["step", "vector"], 3) ==
              Dict("step" => 3, "vector" => vector)

        # multiple variables, multiple steps
        @test adios_load(file, ["step", "vector"], [1, 3, 5]) ==
              Dict("step" => [1, 3, 5], "vector" =>  repeat(vector, 1, 3) )

        close(file)
    end

    @testset "adios_load regex dispatches" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)
        Nsteps = steps(file.engine)

        @test adios_load(file, r"step") == 0:(Nsteps - 1)

        @test adios_load(file, r"vector|matrix", [1, 3, 5]) ==
            Dict("vector" => repeat(vector, 1, 3),
                "matrix" => repeat(matrix, 1, 1, 3))

        @test adios_load(file, r"scalar.*[^\/]+") ==
              Dict("scalar_A" => fill(scalar, Nsteps),
                   "scalar_B" => fill(scalar, Nsteps),
                   "abc_scalar23" => fill(scalar, Nsteps),
                   "scalar234" => fill(scalar, Nsteps))

        @test adios_load(file, r"deep.*scalar") ==
              Dict("deep/in/nested/groups/scalar" => fill(scalar, Nsteps),
                   "another/deep/in/nested/groups/scalar" => fill(scalar, Nsteps))

        close(file)
    end

    @testset "adios_load with bpName directly" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        @test adios_load(bpName) == adios_load(file)
        @test adios_load(bpName, "step") == adios_load(file, "step")
        @test adios_load(bpName, r"scalar") == adios_load(file, r"scalar")

        @test_throws ErrorException adios_load("non-existing-file.bp")
        @test_throws ErrorException adios_load("non-existing-file.bp", "step")

        close(file)
    end
end

@testset "adios_load with multiple step counts" begin
    tmp_dir = Base.Filesystem.mktempdir()

    bpName = "$tmp_dir/test.bp"

    # Define test data
    nn = 3
    scalar = rand()
    vector = rand(nn)
    matrix = rand(nn, nn)
    array3D = rand(nn, nn, nn)

    Nsteps_A = 7
    Nsteps_B = 10

    @testset "Write a test.bp file for test" begin

        # write test.bp data
        file = adios_open_serial(bpName, mode_write)

        # 1-step ('time independent')
        begin_step(file.engine)

        adios_put!(file, "scalar", scalar)
        adios_put!(file, "scalar234", scalar)
        adios_put!(file, "vector", vector)
        adios_put!(file, "matrix", matrix)
        adios_put!(file, "array3D", array3D)

        adios_perform_puts!(file)
        end_step(file.engine)

        # Nsteps_A
        for i in 0:(Nsteps_A - 1)
            begin_step(file.engine)

            adios_put!(file, "step_A", i)

            adios_put!(file, "scalar_A", scalar)
            adios_put!(file, "vector_A", vector)
            adios_put!(file, "matrix_A", matrix)
            adios_put!(file, "array3D_A", array3D)

            end_step(file.engine)
        end

        # Nsteps_B
        for i in 0:(Nsteps_B - 1)
            begin_step(file.engine)

            adios_put!(file, "step_B", i)

            adios_put!(file, "scalar_B", scalar)
            adios_put!(file, "vector_B", vector)
            adios_put!(file, "matrix_B", matrix)
            adios_put!(file, "array3D_B", array3D)

            end_step(file.engine)
        end

        close(file)
    end

    @testset "Load all data at once" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        @test steps(file.engine) == 1 + Nsteps_A + Nsteps_B

        # read test.bp data using adios_load
        all_data = adios_load(file)

        @test all_data["scalar"] == [scalar]
        @test all_data["vector"] == vector
        @test all_data["matrix"] == matrix
        @test all_data["array3D"] == array3D

        @test all_data["step_A"] == 0:(Nsteps_A - 1)
        @test all_data["scalar_A"] == fill(scalar, Nsteps_A)
        @test all_data["vector_A"] == repeat(vector, 1, Nsteps_A)
        @test all_data["matrix_A"] == repeat(matrix, 1, 1, Nsteps_A)
        @test all_data["array3D_A"] == repeat(array3D, 1, 1, 1, Nsteps_A)

        @test all_data["step_B"] == 0:(Nsteps_B - 1)
        @test all_data["scalar_B"] == fill(scalar, Nsteps_B)
        @test all_data["vector_B"] == repeat(vector, 1, Nsteps_B)
        @test all_data["matrix_B"] == repeat(matrix, 1, 1, Nsteps_B)
        @test all_data["array3D_B"] == repeat(array3D, 1, 1, 1, Nsteps_B)

        close(file)
    end

    @testset "Load all data at specific steps" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        # single step
        target_step = 2

        all_data = adios_load(file,target_step)
        @test_throws KeyError all_data["scalar"]
        @test_throws KeyError all_data["vector"]
        @test_throws KeyError all_data["matrix"]
        @test_throws KeyError all_data["array3D"]

        @test all_data["step_A"] == target_step
        @test all_data["scalar_A"] == scalar
        @test all_data["vector_A"] == vector
        @test all_data["matrix_A"] == matrix
        @test all_data["array3D_A"] == array3D

        @test all_data["step_B"] == target_step
        @test all_data["scalar_B"] == scalar
        @test all_data["vector_B"] == vector
        @test all_data["matrix_B"] == matrix
        @test all_data["array3D_B"] == array3D

        # Multiple steps: read data from steps 2 to 5
        target_steps = 2:5
        all_data = adios_load(file,target_steps)

        @test_throws KeyError all_data["scalar"]
        @test_throws KeyError all_data["vector"]
        @test_throws KeyError all_data["matrix"]
        @test_throws KeyError all_data["array3D"]

        @test all_data["step_A"] == target_steps
        @test all_data["scalar_A"] == fill(scalar, length(target_steps))
        @test all_data["vector_A"] == repeat(vector, 1, length(target_steps))
        @test all_data["matrix_A"] == repeat(matrix, 1, 1, length(target_steps))
        @test all_data["array3D_A"] == repeat(array3D, 1, 1, 1, length(target_steps))

        @test all_data["step_B"] == target_steps
        @test all_data["scalar_B"] == fill(scalar, length(target_steps))
        @test all_data["vector_B"] == repeat(vector, 1, length(target_steps))
        @test all_data["matrix_B"] == repeat(matrix, 1, 1, length(target_steps))
        @test all_data["array3D_B"] == repeat(array3D, 1, 1, 1, length(target_steps))

        close(file)
    end

    @testset "adios_load basic dispatches" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        # single variable, all steps
        @test adios_load(file, "scalar") == [scalar]
        @test adios_load(file, "vector") == vector
        @test adios_load(file, "vector"; start=(2,)) == vector[2:end]
        @test adios_load(file, "vector"; count=(2,)) == vector[1:2]
        @test adios_load(file, "vector"; start=(2,), count=(2,)) == vector[2:3]

        @test adios_load(file, "step_A") == 0:(Nsteps_A - 1)
        @test adios_load(file, "vector_A") == repeat(vector, 1, Nsteps_A)
        @test adios_load(file, "vector_A"; start=(2,)) == repeat(vector[2:end], 1, Nsteps_A)
        @test adios_load(file, "vector_A"; count=(2,)) == repeat(vector[1:2], 1, Nsteps_A)
        @test adios_load(file, "vector_A"; start=(2,), count=(2,)) == repeat(vector[2:3], 1, Nsteps_A)

        @test adios_load(file, "step_B") == 0:(Nsteps_B - 1)
        @test adios_load(file, "vector_B") == repeat(vector, 1, Nsteps_B)
        @test adios_load(file, "vector_B"; start=(2,)) == repeat(vector[2:end], 1, Nsteps_B)
        @test adios_load(file, "vector_B"; count=(2,)) == repeat(vector[1:2], 1, Nsteps_B)
        @test adios_load(file, "vector_B"; start=(2,), count=(2,)) == repeat(vector[2:3], 1, Nsteps_B)

        # single variable, specific step (@ step=3)
        @test_throws ErrorException adios_load(file, "scalar", 3)
        @test_throws ErrorException adios_load(file, "array3D", 3)
        @test_throws ErrorException adios_load(file, "array3D", 3; start=(1, 2, 3))
        @test_throws ErrorException adios_load(file, "array3D", 3; count=(2, 2, 1))
        @test_throws ErrorException adios_load(file, "array3D", 3; start=(1, 2, 3), count=(2, 2, 1))

        @test adios_load(file, "step_A", 3) == 3
        @test adios_load(file, "scalar_A", 3) == scalar
        @test adios_load(file, "array3D_A", 3) == array3D
        @test adios_load(file, "array3D_A", 3; start=(1, 2, 3)) == array3D[1:end,2:end,3:end]
        @test adios_load(file, "array3D_A", 3; count=(2, 2, 1)) == array3D[1:2,1:2,1:1]
        @test adios_load(file, "array3D_A", 3; start=(1, 2, 3), count=(2, 2, 1)) == array3D[1:2,2:3,3:3]

        @test adios_load(file, "step_B", 3) == 3
        @test adios_load(file, "scalar_B", 3) == scalar
        @test adios_load(file, "array3D_B", 3) == array3D
        @test adios_load(file, "array3D_B", 3; start=(1, 2, 3)) == array3D[1:end,2:end,3:end]
        @test adios_load(file, "array3D_B", 3; count=(2, 2, 1)) == array3D[1:2,1:2,1:1]
        @test adios_load(file, "array3D_B", 3; start=(1, 2, 3), count=(2, 2, 1)) == array3D[1:2,2:3,3:3]

        # single varialbe, mulitiple steps
        @test_throws ErrorException adios_load(file, "matrix", [1, 3, 5])
        @test_throws ErrorException adios_load(file, "matrix", [1, 3, 5]; start=(2, 1))
        @test_throws ErrorException adios_load(file, "matrix", [1, 3, 5]; count=(2, 1))
        @test_throws ErrorException adios_load(file, "matrix", [1, 3, 5]; start=(2, 1), count=(2, 1))

        @test adios_load(file, "step_A", [1, 3, 5]) == [1, 3, 5]
        @test adios_load(file, "step_A", [5, 3, 1]) == [5, 3, 1]
        @test adios_load(file, "step_A", 1:3) == 1:3
        @test adios_load(file, "matrix_A", [1, 3, 5]) == repeat(matrix, 1, 1, 3)
        @test adios_load(file, "matrix_A", [1, 3, 5]; start=(2, 1)) == repeat(matrix[2:end,1:end], 1, 1, 3)
        @test adios_load(file, "matrix_A", [1, 3, 5]; count=(2, 1)) == repeat(matrix[1:2,1:1], 1, 1, 3)
        @test adios_load(file, "matrix_A", [1, 3, 5]; start=(2, 1), count=(2, 1)) == repeat(matrix[2:3,1:1], 1, 1, 3)

        @test adios_load(file, "step_B", [1, 3, 5]) == [1, 3, 5]
        @test adios_load(file, "step_B", [5, 3, 1]) == [5, 3, 1]
        @test adios_load(file, "step_B", 1:3) == 1:3
        @test adios_load(file, "matrix_B", [1, 3, 5]) == repeat(matrix, 1, 1, 3)
        @test adios_load(file, "matrix_B", [1, 3, 5]; start=(2, 1)) == repeat(matrix[2:end,1:end], 1, 1, 3)
        @test adios_load(file, "matrix_B", [1, 3, 5]; count=(2, 1)) == repeat(matrix[1:2,1:1], 1, 1, 3)
        @test adios_load(file, "matrix_B", [1, 3, 5]; start=(2, 1), count=(2, 1)) == repeat(matrix[2:3,1:1], 1, 1, 3)

        # mulitiple variables, all steps
        @test adios_load(file, ["vector", "step_A", "vector_A", "step_B", "vector_B"]) ==
              Dict("vector" => vector,
                   "step_A" => 0:(Nsteps_A - 1),
                   "vector_A" => repeat(vector, 1, Nsteps_A),
                   "step_B" => 0:(Nsteps_B - 1),
                   "vector_B" => repeat(vector, 1, Nsteps_B))

        # multiple variables, specific step (@ step=3)
        @test_throws ErrorException adios_load(file, ["vector", "matrix"], 3)
        @test adios_load(file, ["step_A", "vector_A", "step_B", "vector_B"], 3) ==
              Dict("step_A" => 3, "vector_A" => vector,
                   "step_B" => 3, "vector_B" => vector)

        # multiple variables, multiple steps
        @test_throws ErrorException adios_load(file, ["vector", "matrix"], [1, 3, 5])
        @test adios_load(file, ["step_A", "vector_A", "step_B", "vector_B"], [1, 3, 5]) ==
              Dict("step_A" => [1, 3, 5], "vector_A" =>  repeat(vector, 1, 3),
                   "step_B" => [1, 3, 5], "vector_B" =>  repeat(vector, 1, 3))

        close(file)
    end

    @testset "adios_load regex dispatches" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)
        Nsteps = steps(file.engine)

        @test adios_load(file, r"step_A") == 0:(Nsteps_A - 1)
        @test adios_load(file, r"step_B") == 0:(Nsteps_B - 1)

        @test adios_load(file, r"vector_A|matrix_B") ==
              Dict("vector_A" => repeat(vector, 1, Nsteps_A),
                   "matrix_B" => repeat(matrix, 1, 1, Nsteps_B))

        @test adios_load(file, r"vector_A|matrix_B", [1, 3, 5]) ==
              Dict("vector_A" => repeat(vector, 1, 3),
                   "matrix_B" => repeat(matrix, 1, 1, 3))

        @test adios_load(file, r"scalar.*[^\/]+") ==
              Dict("scalar_A" => fill(scalar, Nsteps_A),
                   "scalar_B" => fill(scalar, Nsteps_B),
                   "scalar234" => [scalar])

        close(file)
    end

    @testset "adios_load with bpName directly" begin
        file = adios_open_serial(bpName, mode_readRandomAccess)

        @test adios_load(bpName) == adios_load(file)
        @test adios_load(bpName, "step_A") == adios_load(file, "step_A")
        @test adios_load(bpName, r"scalar") == adios_load(file, r"scalar")

        @test_throws ErrorException adios_load("non-existing-file.bp")
        @test_throws ErrorException adios_load("non-existing-file.bp", "step")

        close(file)
    end
end
