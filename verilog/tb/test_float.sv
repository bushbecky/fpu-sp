import fp_wire::*;

module test_float
(
  input  logic reset,
  input  logic clock
);

	timeunit 1ns;
	timeprecision 1ps;

	integer data_file;
	integer scan_file;

	logic [31:0] dataread [0:3];

	typedef struct packed{
		logic [31:0] data1;
		logic [31:0] data2;
		logic [31:0] data3;
		logic [31:0] result;
		logic [4:0] flags;
		logic [1:0] fmt;
		logic [2:0] rm;
		fp_operation_type op;
		logic [0:0] enable;
		logic [31:0] result_orig;
		logic [31:0] result_calc;
		logic [31:0] result_diff;
		logic [4:0] flags_orig;
		logic [4:0] flags_calc;
		logic [4:0] flags_diff;
		logic [0:0] terminate;
	} fp_result;

	fp_result init_fp_res = '{
		data1 : 0,
		data2 : 0,
		data3 : 0,
		result : 0,
		flags : 0,
		fmt : 0,
		rm : 0,
		op : init_fp_operation,
		enable : 0,
		result_orig : 0,
		result_calc : 0,
		result_diff : 0,
		flags_orig : 0,
		flags_calc : 0,
		flags_diff : 0,
		terminate : 0
	};

	fp_result v;
	fp_result r,rin;

	fp_unit_in_type fp_unit_i;
	fp_unit_out_type fp_unit_o;

	string operation [0:6] = '{"f32_le","f32_lt","f32_eq","i32_to_f32","ui32_to_f32","f32_to_i32","f32_to_ui32"};
	string mode [0:4] = '{"rne","rtz","rdn","rup","rmm"};
	logic [0:0] round [0:6] = '{0,0,0,1,1,1,1};
	logic [0:0] cmp [0:6] = '{1,1,1,0,0,0,0};
	logic [0:0] i2f [0:6] = '{0,0,0,1,1,0,0};
	logic [0:0] f2i [0:6] = '{0,0,0,0,0,1,1};
	logic [2:0] rm [0:6] = '{0,1,2,0,0,0,0};
	logic [1:0] op [0:6] = '{0,0,0,0,1,0,1};
	logic [2:0] rnd [0:4] = '{0,1,2,3,4};

	string filename;

	logic load;

	integer i;
	integer j;

	always_comb begin

		@(posedge clock);

		if (reset == 0) begin
			load = 0;
			i = 0;
			j = 0;
		end

		if (round[i] == 0) begin

			if (load == 0) begin
				filename = {operation[i],".hex"};
				data_file = $fopen(filename, "r");
				if (data_file == 0) begin
					$display({filename," is not available!"});
					$finish;
				end
				load = 1;
			end

			v = init_fp_res;

			if ($feof(data_file)) begin
				v.enable = 1;
				v.terminate = 1;
				dataread = '{default:0};
			end else begin
				v.enable = 1;
				v.terminate = 0;
				scan_file = $fscanf(data_file,"%h %h %h %h\n", dataread[0], dataread[1], dataread[2], dataread[3]);
			end

			v.data1 = dataread[0];
			v.data2 = dataread[1];
			v.data3 = 0;
			v.result = dataread[2];
			v.flags = dataread[3][4:0];
			v.fmt = 0;
			v.rm = rm[i];
			v.op.fmadd = 0;
			v.op.fadd = 0;
			v.op.fsub = 0;
			v.op.fmul = 0;
			v.op.fdiv = 0;
			v.op.fsqrt = 0;
			v.op.fcmp = cmp[i];
			v.op.fcvt_i2f = i2f[i];
			v.op.fcvt_f2i = f2i[i];
			v.op.fcvt_op = op[i];

			if (reset == 0) begin
				v.op = init_fp_operation;
				v.enable = 0;
			end

			fp_unit_i.fp_exe_i.data1 = v.data1;
			fp_unit_i.fp_exe_i.data2 = v.data2;
			fp_unit_i.fp_exe_i.data3 = v.data3;
			fp_unit_i.fp_exe_i.fmt = v.fmt;
			fp_unit_i.fp_exe_i.rm = v.rm;
			fp_unit_i.fp_exe_i.op = v.op;
			fp_unit_i.fp_exe_i.enable = v.enable;

			v.result_orig = r.result;
			v.flags_orig = r.flags;

			v.result_calc = fp_unit_o.fp_exe_o.result;
			v.flags_calc = fp_unit_o.fp_exe_o.flags;

			if ((v.op.fcvt_f2i == 0 && v.op.fcmp == 0) && v.result_calc[31:0] == 32'h7FC00000) begin
				v.result_diff = {1'h0,v.result_orig[30:22] ^ v.result_calc[30:22],22'h0};
			end else begin
				v.result_diff = v.result_orig ^ v.result_orig;
			end
			v.flags_diff = v.flags_orig ^ v.flags_calc;

			if (v.terminate == 1) begin
				$write("%c[1;34m",8'h1B);
				$display(operation[i]);
				$write("%c[0m",8'h1B);
				$write("%c[1;32m",8'h1B);
				$display("TEST SUCCEEDED");
				$write("%c[0m",8'h1B);
				$finish;
			end else if ((v.result_diff != 0) || (v.flags_diff != 0)) begin
				$write("%c[1;34m",8'h1B);
				$display(operation[i]);
				$write("%c[0m",8'h1B);
				$write("%c[1;31m",8'h1B);
				$display("TEST FAILED");
				$display("A                 = 0x%H",r.data1);
				$display("B                 = 0x%H",r.data2);
				$display("C                 = 0x%H",r.data3);
				$display("RESULT DIFFERENCE = 0x%H",v.result_diff);
				$display("RESULT REFERENCE  = 0x%H",v.result_orig);
				$display("RESULT CALCULATED = 0x%H",v.result_calc);
				$display("FLAGS DIFFERENCE  = 0x%H",v.flags_diff);
				$display("FLAGS REFERENCE   = 0x%H",v.flags_orig);
				$display("FLAGS CALCULATED  = 0x%H",v.flags_calc);
				$write("%c[0m",8'h1B);
				$finish;
			end

			rin = v;

		end else begin

			if (load == 0) begin
				filename = {operation[i],"_",mode[j],".hex"};
				data_file = $fopen(filename, "r");
				if (data_file == 0) begin
					$display({filename," is not available!"});
					$finish;
				end
				load = 1;
			end

			v = init_fp_res;

			if ($feof(data_file)) begin
				v.enable = 1;
				v.terminate = 1;
				dataread = '{default:0};
			end else begin
				v.enable = 1;
				v.terminate = 0;
				scan_file = $fscanf(data_file,"%h %h %h\n", dataread[0], dataread[1], dataread[2]);
			end

			v.data1 = dataread[0];
			v.data2 = 0;
			v.data3 = 0;
			v.result = dataread[1];
			v.flags = dataread[2][4:0];
			v.fmt = 0;
			v.rm = rnd[j];
			v.op.fmadd = 0;
			v.op.fadd = 0;
			v.op.fsub = 0;
			v.op.fmul = 0;
			v.op.fdiv = 0;
			v.op.fsqrt = 0;
			v.op.fcmp = cmp[i];
			v.op.fcvt_i2f = i2f[i];
			v.op.fcvt_f2i = f2i[i];
			v.op.fcvt_op = op[i];

			if (reset == 0) begin
				v.op = init_fp_operation;
				v.enable = 0;
			end

			fp_unit_i.fp_exe_i.data1 = v.data1;
			fp_unit_i.fp_exe_i.data2 = v.data2;
			fp_unit_i.fp_exe_i.data3 = v.data3;
			fp_unit_i.fp_exe_i.fmt = v.fmt;
			fp_unit_i.fp_exe_i.rm = v.rm;
			fp_unit_i.fp_exe_i.op = v.op;
			fp_unit_i.fp_exe_i.enable = v.enable;

			v.result_orig = r.result;
			v.flags_orig = r.flags;

			v.result_calc = fp_unit_o.fp_exe_o.result;
			v.flags_calc = fp_unit_o.fp_exe_o.flags;

			if ((v.op.fcvt_f2i == 0 && v.op.fcmp == 0) && v.result_calc[31:0] == 32'h7FC00000) begin
				v.result_diff = {1'h0,v.result_orig[30:22] ^ v.result_calc[30:22],22'h0};
			end else begin
				v.result_diff = v.result_orig ^ v.result_orig;
			end
			v.flags_diff = v.flags_orig ^ v.flags_calc;

			if (v.terminate == 1) begin
				$write("%c[1;34m",8'h1B);
				$display({operation[i]," ",mode[j]});
				$write("%c[0m",8'h1B);
				$write("%c[1;32m",8'h1B);
				$display("TEST SUCCEEDED");
				$write("%c[0m",8'h1B);
				$finish;
			end else if ((v.result_diff != 0) || (v.flags_diff != 0)) begin
				$write("%c[1;34m",8'h1B);
				$display({operation[i]," ",mode[j]});
				$write("%c[0m",8'h1B);
				$write("%c[1;31m",8'h1B);
				$display("TEST FAILED");
				$display("A                 = 0x%H",r.data1);
				$display("B                 = 0x%H",r.data2);
				$display("C                 = 0x%H",r.data3);
				$display("RESULT DIFFERENCE = 0x%H",v.result_diff);
				$display("RESULT REFERENCE  = 0x%H",v.result_orig);
				$display("RESULT CALCULATED = 0x%H",v.result_calc);
				$display("FLAGS DIFFERENCE  = 0x%H",v.flags_diff);
				$display("FLAGS REFERENCE   = 0x%H",v.flags_orig);
				$display("FLAGS CALCULATED  = 0x%H",v.flags_calc);
				$write("%c[0m",8'h1B);
				$finish;
			end

			rin = v;

		end
	end

	always_ff @(posedge clock) begin
		if (reset == 0) begin
			r <= init_fp_res;
		end else begin
			r <= rin;
		end
	end

	fp_unit fp_unit_comp
	(
		.reset ( reset ),
		.clock ( clock ),
		.fp_unit_i ( fp_unit_i ),
		.fp_unit_o ( fp_unit_o )
	);

endmodule
