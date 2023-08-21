class transaction;
    rand bit [7:0] addr, din;
    bit [7:0] dout;
    bit done, err;
    rand bit wr ; 

  constraint address_range {addr inside {[0:31]};}; 
//   constraint write_enable {wr inside {1'b1};}; 
  
  function void display(string name);
    $display("---------------------------------");
    $display (" %s ",name);
    $display("---------------------------------");
    $display(" address=%b, data=%b, dout=%b", addr, din ,dout);
    $display("---------------------------------");
  endfunction
  
  
endclass



class generator;
  
  mailbox gen2driv;
  transaction trans;
  event scb_done;
  int  repeat_count;

  
  function new (mailbox gen2driv, event scb_done);
    this.gen2driv=gen2driv;
    this.scb_done = scb_done; 
  endfunction
  
  task main();
    repeat (12) begin
      $display ("This 4"); 
      trans = new();
      if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");
        trans.display("[ Generator ]");
        gen2driv.put(trans);
        @scb_done;

    end

     //triggering indicatesthe end of generation
  endtask
  
endclass


class driver;
  mailbox gen2driv; 
  transaction trans;
  virtual  inter_f int_v;
  event drive_done; 
  
  function new (virtual  inter_f int_v,mailbox gen2driv, event drive_done);
    this.gen2driv=gen2driv;
    this.int_v=int_v;
    this.drive_done = drive_done; 
  endfunction
  
  task reset;
    @(posedge int_v.clk && int_v.rst )
        $display(" ----------------------------");

    $display("reseting !!!!!!!!!!!!!!!!!!!");
    int_v.addr <=0;
    int_v.din <=0;
    int_v.dout <=0;
    int_v.done <=0;
    int_v.err<=0;
    $display(" ----------------------------");

  endtask:reset
  
  task main();
    forever
      begin
        gen2driv.get(trans);
        @(posedge int_v.clk );
        int_v.wr<=trans.wr;
        int_v.addr <=trans.addr;
        int_v.din <=trans.din;
        int_v.dout <=trans.dout;
        int_v.done <=trans.done; 
        int_v.err <=trans.err;  
        -> drive_done;



      end
  endtask
endclass




class monitor;
  
  mailbox mon2scr;
  transaction trans;  
  virtual  inter_f int_v;
  event drive_done; 
  
  function new (virtual  inter_f int_v,mailbox mon2scr, event drive_done);
    this.mon2scr=mon2scr;
    this.int_v=int_v;
    this.drive_done = drive_done; 
  endfunction

  task main();
    @drive_done; 
	forever begin
      transaction trans;
      trans = new();
      @(posedge int_v.clk);
        trans.wr<=int_v.wr;
        trans.addr <=int_v.addr;
        trans.din <=int_v.din;
        trans.dout <=int_v.dout;
        trans.done <=int_v.done; 
        trans.err <=int_v.err;   

      trans.display("[ Monitor ]");
    end
  endtask
endclass


interface inter_f (input bit clk, input bit rst);
  logic wr,  done, err; 
  logic [7:0] addr, din, dout;
endinterface



class environment;
  generator gen;
  driver driv;
  monitor mon;
  scoreboard scb;
  mailbox gen2driv;
  mailbox mon2scb;
  event drive_done;
  event scb_done; 

virtual inter_f int_v;
  
  function new(virtual inter_f int_v);
    this.int_v=int_v;
    gen2driv=new();
    mon2scb=new ();
    gen=new (gen2driv,scb_done);
    driv=new (int_v,gen2driv, drive_done);
    mon=new (int_v,mon2scb, drive_done);
    scb=new(mon2scb, scb_done);
  endfunction
  
  task test();
    fork
      gen.main();
      driv.main();
      mon.main();
      scb.main();
//       driv.reset();

    join_any
  endtask
  
  
  task run;

    test();

 $finish;
  endtask
  
endclass

class scoreboard;
   
  //creating mailbox handle
  mailbox mon2scb;
  
  //used to count the number of transactions
  int no_transactions;
  event scb_done;
  
  transaction trans; 
  
  
  //constructor
  function new(mailbox mon2scb, event scb_done);
    this.mon2scb = mon2scb;
    this.scb_done = scb_done; 
  endfunction
  
  task main (); 
    forever begin
      
      trans = new (); 
      mon2scb.get (trans);
      -> scb_done; 

// //       $display ("This is illegal address!");  
      
// //       if (trans.addr > 32) $display ("This is illegal address!");  
// //       else $display ("This is correct address!"); 
// //       trans.display ("SCORE BOARD"); 
    

    end 

  endtask 
endclass


program test(inter_f i_intf);
  
  //declaring environment instance
  environment env;
  
  initial begin
    //creating environment
    env = new(i_intf);
    
    //setting the repeat count of generator as 4, means to generate 4 packets
    env.gen.repeat_count = 4;
    
    //calling run of env, it interns calls generator and driver main tasks.
    env.run();
  end
endprogram

module tb;
  
  bit clk, rst;
  inter_f int_f(clk, rst);
  test t(int_f);
  
   always #10 clk=~ clk;
   initial begin 
    $dumpfile("dump.vcd"); 
     $dumpvars;
     clk=1;

     rst=1;
     #10;
     rst=0;
     #1000;$finish;
  end

  top spi_full_package(
    .clk(int_f.clk),
    .wr(int_f.wr),
    .addr(int_f.addr),
    .din(int_f.din),
    .dout(int_f.dout),
    .err(int_f.err),
    .rst(int_f.rst),
    .done(int_f.done)

  );
  
  
endmodule


