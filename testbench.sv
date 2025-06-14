`include "uvm_macros.svh"
import uvm_pkg::*;
 
///transaction class

class transaction extends uvm_sequence_item;
`uvm_object_utils(transaction)
  
   rand bit [3:0] a;
   rand bit [3:0] b;
        bit [7:0] y;
        
   function new(input string path = "transaction");
    super.new(path);
   endfunction
  
 
endclass

 
///sequence class - creates random seq and sends to the sequencer which then sends it to the driver

class generator extends uvm_sequence#(transaction);
`uvm_object_utils(generator)
  
    transaction tr;
 
   function new(input string path = "generator");
    super.new(path);
   endfunction
   
   ///calling the start() method in test top will automatically run this body
   virtual task body(); 
   repeat(15)
     begin
         tr = transaction::type_id::create("tr");
         start_item(tr);
         assert(tr.randomize());
         `uvm_info("SEQ", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE);
         finish_item(tr);     
     end
   endtask
 
endclass


///driver class - send the transacion received from the sequencer to the DUT
 
class drv extends uvm_driver#(transaction);
  `uvm_component_utils(drv)
 
  transaction tr;
  virtual mul_if mif;
 
  function new(input string path = "drv", uvm_component parent = null);
    super.new(path,parent);
  endfunction
 
 ///use uvm_config_db get method to access the interface - set method is declared in the tb top
  virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    if(!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface");
  endfunction
  

  ///the seq_item_port is already declared inside uvm_driver - we can directly use the get_next_item and item_done methods
   virtual task run_phase(uvm_phase phase);
      tr = transaction::type_id::create("tr");
     forever begin
        seq_item_port.get_next_item(tr);
        mif.a <= tr.a;
        mif.b <= tr.b;
       `uvm_info("DRV", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE);
        seq_item_port.item_done();
        #20;   
      end
   endtask
 
endclass
 

///monitor class - it gets the result from the DUT and send it to the scoreboard

class mon extends uvm_monitor;
`uvm_component_utils(mon)
 
uvm_analysis_port#(transaction) send; //we use analysis port to connect with scoreboard - import is declared in sco
transaction tr;
virtual mul_if mif;
 
    function new(input string inst = "mon", uvm_component parent = null);
    super.new(inst,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tr = transaction::type_id::create("tr");
    send = new("send", this);
    if(!uvm_config_db#(virtual mul_if)::get(this,"","mif",mif))//uvm_test_top.env.agent.drv.aif
      `uvm_error("drv","Unable to access Interface");
    endfunction
    
    
    virtual task run_phase(uvm_phase phase);
    forever begin
    #20;
    tr.a = mif.a;
    tr.b = mif.b;
    tr.y = mif.y;
    `uvm_info("MON", $sformatf("a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE);
    send.write(tr); //write method will be implemented in the sco
    end
   endtask 
 
endclass
 
///scoreboard class - checks the result 
class sco extends uvm_scoreboard;
`uvm_component_utils(sco)
 
  uvm_analysis_imp#(transaction,sco) recv;
 
 
    function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
    endfunction
    
    ///the argument will receive the transcation sent from the monitor
  virtual function void write(transaction tr);
      if(tr.y == (tr.a * tr.b))
         `uvm_info("SCO", $sformatf("Test Passed -> a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y), UVM_NONE)
      else
         `uvm_error("SCO", $sformatf("Test Failed -> a : %0d  b : %0d  y : %0d", tr.a, tr.b, tr.y))
      
    $display("----------------------------------------------------------------");
    endfunction
 
endclass
 
///agent class (mon, drv, seqr) - connects the drv and seqr
 
class agent extends uvm_agent;
`uvm_component_utils(agent)
 
function new(input string inst = "agent", uvm_component parent = null);
super.new(inst,parent);
endfunction
 
 drv d;
 uvm_sequencer#(transaction) seqr; ///sequencer class
 mon m;
 
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
 d = drv::type_id::create("d",this);
 m = mon::type_id::create("m",this);
 seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
endfunction
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
d.seq_item_port.connect(seqr.seq_item_export); ///TLM port export connection
endfunction
 
endclass
 
///env class (agent, sco) - connects the monitor and sco
 
class env extends uvm_env;
`uvm_component_utils(env)
 
function new(input string inst = "env", uvm_component c);
super.new(inst,c);
endfunction
 
agent a;
sco s;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  a = agent::type_id::create("a",this);
  s = sco::type_id::create("s", this);
endfunction
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
a.m.send.connect(s.recv); //TLM port-imp connection
endfunction
 
endclass
 
 
///test top class - we start the seq generation using the start method in this class

class test extends uvm_test;
`uvm_component_utils(test)
 
function new(input string inst = "test", uvm_component c);
super.new(inst,c);
endfunction
 
env e;
generator gen;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  e   = env::type_id::create("env",this);
  gen = generator::type_id::create("gen");
endfunction
 
virtual task run_phase(uvm_phase phase);
phase.raise_objection(this);
gen.start(e.a.seqr); // this will start the body function in the seq class (generator)
#20;
phase.drop_objection(this);
endtask
endclass
 
 
///tb module - we declare the dut and interface here - we implement the set method here to send access to interface to other classes - and we start the run_test from here
module tb;
 
  mul_if mif();
  
  mul dut (.a(mif.a), .b(mif.b), .y(mif.y));
 
  initial 
  begin
  uvm_config_db #(virtual mul_if)::set(null, "*", "mif", mif);
  run_test("test"); 
  end
 
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
 
 