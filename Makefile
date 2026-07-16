# UART controller - simulation with Icarus Verilog
IV      = iverilog -g2012
VVP     = vvp
RTL     = rtl/uart_tx.v rtl/uart_rx.v
TB      = tb/tb_uart.v
BUILD   = build

.PHONY: test wave clean
test: ## compile + run the self-checking loopback testbench
	@mkdir -p $(BUILD)
	$(IV) -o $(BUILD)/sim.vvp $(RTL) $(TB)
	$(VVP) $(BUILD)/sim.vvp

wave: ## regenerate the reference waveform SVG in docs/
	@mkdir -p $(BUILD)
	$(IV) -o $(BUILD)/sim.vvp $(RTL) $(TB)
	cd docs && $(VVP) ../$(BUILD)/sim.vvp >/dev/null
	python3 tools/vcd2svg.py docs/uart.vcd docs/uart_wave.svg \
		tx_start tx_data serial rx_valid rx_data \
		--title "UART loopback: TX 0x55 over serial line, RX recovers 0x55" \
		--from 4000000 --to 95000000

clean:
	rm -rf $(BUILD) docs/*.vcd

synth: ## quick synthesizability check with Yosys
	yosys -p "read_verilog rtl/uart_tx.v; synth -top uart_tx"
	yosys -p "read_verilog rtl/uart_rx.v; synth -top uart_rx"
