# How to run the code

run ```sudo docker run -ti phisco/plumberz``` and go into the ```/code``` directory.

1.  **wordcount_mapReduce.hs**: batch wordcount, reads from "test-text.txt" the text and counts the number of words in it, using pipes. Can be run by: ```stack runghc wordcount_mapReduce.hs```
2.  **tubes_FastWordCount.hs**: same as wordcount_mapReduce.hs, but with tubes. Can be run by:```stack runghc tubes_FastWordCount.hs```
3. **tubes_WordCount.hs**: same as previous two examples but not slower because tries to do it the dataflow way . Can be run by: ```stack runghc tubes_WordCount.hs ```
4.  **Wordcount.hs**: timed wordcount in pipes, tries to count the words inside a tumbling window of 5 seconds. Can be run by: ```cat test-text.txt | stack runghc Wordcount.hs``` or ```stack runghc Wordcount.hs``` with input from keyboard.
If run by:```yes `cat test-text.txt` | stack runghc Wordcount.hs``` no output is printed.
5.  **wordcount_flink_v1.hs**: timed wordcount in pipes that tries to solve problem with previous version, rate is not a problem anymore but output is printed only if some input arrives after the window closing. Can be run by ```yes `cat test-text.txt` | stack runghc wordcount_flink_v1.hs``` and behaves correctly due to the high rate of the input, if run with input from keyboard the erroneous behavior can be perceived ```yes `stack runghc wordcount_flink_v1.hs``` for example pressing "enter" for a second or so and then waiting for the 5 second window to close, one can see that no output is given untill a further enter is given, due to the blocking nature of the implementation.
6.  **wordcount_flink_v2.hs**: timed wordcount in pipes that tries to solve the previous version problem with low rate input. Can be run by ```yes `cat test-text.txt` | stack runghc wordcount_flink_v2.hs``` or with input from keyboard just ```stack runghc wordcount_flink_v2.hs``` and in both cases it behaves as expected. The reporting policy here reports also if the no characters have been received.

5 and 6 if run by ```yes | stack runghc $filename``` show pretty different performances, due to the fact that in 5 we were trying to adopt the approach of CQL, dividing in s2r, r2r and r2s, whereas in 6 we merged the s2r and r2r part achieving better performances.
As said 4 does not work if run with this input, due to problems in the implementation of the mailboxes in pipes-concurrent. But we were not able to be 100% sure of the cause of the problem.
