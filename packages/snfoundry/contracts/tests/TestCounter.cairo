use  snforge_std::{declare,DeclareResultTrait,ContractClassTrait,spy_events,EventSpyAssertionsTrait,start_cheat_caller_address,stop_cheat_caller_address};
use starknet::{ContractAddress,};
use contracts::Counter::{ICounterDispatcher,ICounterDispatcherTrait,Counter,ICounterSafeDispatcher, ICounterSafeDispatcherTrait};
use openzeppelin_access::ownable::interface::{IOwnableDispatcher,IOwnableDispatcherTrait};
const ZERO_COUNT:u32 = 0;
fn OWNER() -> ContractAddress {
    'OWNER'.try_into().unwrap()
}


fn USER1() -> ContractAddress {
    'USER1'.try_into().unwrap()
}

fn __deploy__(initial_value:u32) -> (ICounterDispatcher,IOwnableDispatcher,ICounterSafeDispatcher) {
    // declare
    let contract_class = declare("Counter").unwrap().contract_class();
//serialize constructor

let mut calldata:Array<felt252> = array![];
initial_value.serialize(ref calldata);
OWNER().serialize(ref calldata);

// deploy contract
let (contract_address,_) = contract_class.deploy(@calldata).expect('failed to deploy');

let counter = ICounterDispatcher{contract_address : contract_address};
let ownable = IOwnableDispatcher{contract_address : contract_address};
let safe_dispatcher = ICounterSafeDispatcher{contract_address: contract_address};
(counter, ownable,safe_dispatcher)

}

#[test]
fn test_counter_deployment(){
let (counter,ownable,_) = __deploy__(ZERO_COUNT);
let count_1 = counter.getCounter();
assert(count_1 == ZERO_COUNT, 'count still at zero');
assert(ownable.owner() == OWNER(),'owner not set');
}

//increase counter


#[test]
fn test_counter_increase(){
 let (counter,_,_) = __deploy__(ZERO_COUNT); 
 let count_1 = counter.getCounter();  
counter.increase_counter();

let increaseCounter = counter.getCounter();
assert(increaseCounter == count_1 + 1, 'invalid count');

}

#[test]
fn test_emitted_increase_events() {
let (counter,_,_) = __deploy__(ZERO_COUNT);
let mut spy = spy_events();
 start_cheat_caller_address(counter.contract_address,USER1());
 counter.increase_counter();
 stop_cheat_caller_address(counter.contract_address);
 spy.assert_emitted(@array![
    (counter.contract_address, Counter::Event::Increased(Counter::Increased{account:USER1()}))
 ]);

spy.assert_not_emitted(@array![
    (counter.contract_address, Counter::Event::Decreased(Counter::Decreased{account:USER1()}))
 ]);

}

#[test]
#[feature("safe_dispatcher")]
fn test_safe_panic(){
    
    let (counter,_,safe_dispatcher) = __deploy__(ZERO_COUNT);
    assert(counter.getCounter() == ZERO_COUNT,'invalid number');
    
    match safe_dispatcher.decrease_counter(){
        
        Result::Ok(_) => {
           panic!("expected error but got ok");
        },
        Result::Err(e) => {
            
        assert(*e[0] == 'decreasing an empty number',*e[0]);
        },
    }
    return ();
   
}


#[test]
#[should_panic]
fn test_counter_decrease_panic(){
    
    let (counter,_,_) = __deploy__(ZERO_COUNT);
    assert(counter.getCounter() == ZERO_COUNT,'invalid number');
    counter.decrease_counter();
}



#[test]
fn test_decrease_success(){
    let value :u32 = 5;
let (counter,_,_) = __deploy__(value);
let initial_value = counter.getCounter();
assert(initial_value == value, 'not the value');

counter.decrease_counter();
let final_value = counter.getCounter();

assert(final_value == initial_value - 1, 'not right');
}

#[ignore]
#[test]
fn test_only_owner_reset(){
    let (counter,_,_) = __deploy__(5);
    start_cheat_caller_address(counter.contract_address,OWNER());
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);
    assert(counter.getCounter() == ZERO_COUNT,'invalid amount');
}


#[test]
#[feature("safe_dispatcher")]
fn test_not_owner_panic(){
    
    let (counter,_,safe_dispatcher) = __deploy__(5);
    
    start_cheat_caller_address(counter.contract_address, USER1());
    match safe_dispatcher.reset_counter(){
        Result::Ok(_) =>{ panic!("not owner");
        },
        Result::Err(e) => {assert(*e[0] == 'non owner cannot reset',*e[0]);
        }
    }
}